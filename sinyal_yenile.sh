#!/usr/bin/env bash
# SINYAL_YENILE — kod dogru, EKRAN ESKI.
#
# ⚠ TESHIS:
#   sinyal_kredi SQL'i ZATEN net_pozisyon'a bakiyor (dun duzeltmisiz) ve
#   "kredi limiti TANIMSIZ" ayrimini yapiyor. MUTAFLAR alarm listesinde YOK — dogru.
#   AMA ekrandaki alarmlar 02:31'de, SQL'in ESKI haliyle uretilmis:
#     ERDOGANLAR "limitin 3.523.352 kati" diyor — limiti 1,00 TL, yani TANIMSIZ.
#     FEVZI BILEN (limit 0,00) dogru sekilde "TANIMSIZ" diyor.
#   Dosya duzeltilmis, SINYALLER YENIDEN KURULMAMIS.
#
# ⚠ KENDI SQL'IMI YAZMIYORUM. Motorun kendi fonksiyonunu (erp_ingest.turet) cagiriyorum.
#   Ayni isi iki yerde yapan iki kod, er ya da gec iki gercek uretir.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TENANT="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ONCE — bozuk basliklar ############"
$PSQL -c "
SELECT left(baslik, 62) AS baslik, (detay->>'limit')::numeric AS limit
  FROM bi_sinyal WHERE tur='kredi_asimi'
 ORDER BY tutar_tl DESC;"

echo
echo "############ 2) MOTORU CAGIR — erp_ingest.turet('musteri_risk') ############"
docker exec krb-assessment python3 -c "
import sys; sys.path.insert(0, '/app')
import erp_ingest, json
r = erp_ingest.turet('$TENANT', 'musteri_risk')
print(json.dumps(r, ensure_ascii=False, indent=2))
" || { echo "  ❌ motor calismadi"; exit 1; }

echo
echo "############ 3) SONRA — basliklar duzeldi mi? ############"
$PSQL -c "
SELECT left(baslik, 62) AS baslik,
       round(tutar_tl/1e6, 1) AS net_M,
       (detay->>'limit')::numeric AS limit
  FROM bi_sinyal WHERE tur='kredi_asimi'
 ORDER BY tutar_tl DESC;"
echo "  ⚠ Limiti 1 TL veya 0 olanlar 'TANIMSIZ' demeli, 'X katı' DEGIL."

echo
echo "############ 4) ⚠ MUTAFLAR alarm listesinde YOK olmali (net 1,0M = limit) ############"
$PSQL -c "SELECT count(*) AS mutaflar_alarmi FROM bi_sinyal
          WHERE tur='kredi_asimi' AND baslik ILIKE '%MUTAFLAR%';"
echo "  ⚠ 0 olmali. 1 ise sistem hala brute bakiyor demektir."

echo
echo "############ 5) ⚠ ASIL BULGU — KREDI LIMITI YONETIMI ############"
$PSQL -c "
SELECT count(*)                                                      AS bakiyeli_musteri,
       count(*) FILTER (WHERE kredi_limiti <= 1)                     AS limiti_YOK,
       count(*) FILTER (WHERE kredi_limiti > 1)                      AS limiti_var,
       round(sum(net_pozisyon) FILTER (WHERE kredi_limiti <= 1)/1e6, 1) AS limitsiz_alacak_M
  FROM master_musteri
 WHERE son_bakiye IS NOT NULL AND net_pozisyon > 0;"
echo
echo "  --- limiti OLMAYAN en buyuk alacaklar (limit KARARI bekliyor) ---"
$PSQL -c "
SELECT left(musteri_adi, 34) AS musteri,
       round(net_pozisyon/1e3) AS net_bin,
       round(vadesi_gecmis/1e3) AS gecikmis_bin
  FROM master_musteri
 WHERE net_pozisyon > 5e5 AND kredi_limiti <= 1
 ORDER BY net_pozisyon DESC LIMIT 10;"
echo "  ⚠ Bunlar 'limit asildi' DEGIL. 'Limit HIC KONULMAMIS'."
echo "     Birincisi ihlal — mudahale ister. Ikincisi bosluk — KARAR ister."
