#!/usr/bin/env bash
# Yukleme stratejisini BU belirleyecek. Once oku, sonra yukle.
# Hicbir sey YAZMAZ. Salt okuma.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ERP tablolari: satir, tarih NULL orani, tazelik ############"
echo "   ⚠ NULL tarih orani KRITIK: Excel gun>12 olanlari METIN birakti."
echo "     Ingest metni parse edemediyse o satirlar NULL/dusuk. Satislarin %54'u."
$PSQL -c "
SELECT c.table_name,
       (xpath('/row/c/text()',
        query_to_xml(format('SELECT count(*) AS c FROM %I', c.table_name),
                     false,true,'')))[1]::text::int AS satir
  FROM information_schema.tables c
 WHERE c.table_schema='public' AND c.table_name LIKE 'bi_%'
 ORDER BY 2 DESC NULLS LAST LIMIT 25;"

echo
echo "############ 2) SATIS FATURALARI — tarih NULL mi, mukerrer var mi? ############"
$PSQL -c "\d bi_satis_faturalari" | sed -n '1,40p'
$PSQL -c "
SELECT count(*)                                        AS toplam,
       count(*) FILTER (WHERE fatura_tarihi IS NULL)   AS tarihi_NULL,
       count(*) FILTER (WHERE vade_tarihi   IS NULL)   AS vadesi_NULL,
       min(fatura_tarihi) AS en_eski, max(fatura_tarihi) AS en_yeni
  FROM bi_satis_faturalari;"

echo
echo "############ 3) ⚠ DOGAL ANAHTAR — ne mukerrersiz? ############"
echo "   Excel'de: Belge Numarasi + Kalem Numarasi. DB'de karsiligi var mi?"
$PSQL -c "
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_name='bi_satis_faturalari' ORDER BY ordinal_position;"

echo "   -- belge+kalem KAC KEZ tekrar ediyor? (1 ise anahtar temiz) --"
$PSQL -c "
SELECT tekrar, count(*) AS kac_grup FROM (
  SELECT count(*) AS tekrar FROM bi_satis_faturalari
   GROUP BY fatura_no, kalem_kodu) t
 GROUP BY 1 ORDER BY 1 LIMIT 10;" 2>/dev/null \
 || echo "   (kolon adlari farkli -- yukaridaki listeye bak)"

echo
echo "############ 4) ⚠ UNIQUE INDEX VAR MI? (yoksa upsert IMKANSIZ) ############"
$PSQL -c "
SELECT tablename, indexname, indexdef FROM pg_indexes
 WHERE tablename LIKE 'bi_%' AND indexdef ILIKE '%UNIQUE%'
 ORDER BY 1;"
echo "   ^ Bos ise: ON CONFLICT kullanamayiz. Once unique index kurulmali,"
echo "     ama mevcut MUKERRERLER temizlenmeden unique index kurulamaz."

echo
echo "############ 5) INGEST nasil yukluyor — INSERT mi, UPSERT mi? ############"
grep -rn "bi_satis_faturalari" /opt/krb-assessment/*.mjs /opt/krb-assessment/*.js 2>/dev/null \
  | grep -i "insert\|conflict\|delete\|truncate\|copy" | head -12
echo "   ^ 'ON CONFLICT' YOKSA: ayni dosyayi 2 kez yuklemek satirlari IKIYE KATLAR."

echo
echo "############ 6) ingest log — en son ne, ne zaman girdi? ############"
$PSQL -c "
SELECT query_type, count(*) AS calisma, max(processed_at) AS son,
       (CURRENT_DATE - max(processed_at)::date) AS gun_once
  FROM bi_ingestion_log GROUP BY 1 ORDER BY 4 DESC;"

echo
echo "############ 7) MUKERRER TESTI — bugun ayni veri 2 kez mi girmis? ############"
$PSQL -c "
SELECT fatura_no, kalem_kodu, count(*) AS kez
  FROM bi_satis_faturalari
 GROUP BY 1,2 HAVING count(*) > 1
 ORDER BY 3 DESC LIMIT 10;" 2>/dev/null || true

echo
echo "==================================================================="
echo " KARAR TABLOSU (yukaridaki ciktilara gore):"
echo "   • unique index VAR  + ingest ON CONFLICT  -> guvenle yeniden yukle"
echo "   • unique index YOK  veya duz INSERT       -> tenant-scoped"
echo "     DELETE + reload (tek islemde). Mukerrer riski sifir."
echo "   • fatura_tarihi NULL orani yuksek         -> eksik satirlar"
echo "     zaten hic girmemis. Reload sadece duzeltmez, TAMAMLAR."
echo "==================================================================="
