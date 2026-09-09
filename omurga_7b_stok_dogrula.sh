#!/usr/bin/env bash
# STOK DOĞRULA — bugünkü değer ~235M mi (ağırlıklı ort) + reconstruction viable mi + #100 donma. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ⚠ #100 — hareket akışı canlı mı? belge_tarihi aralığı + son 8 ay aylık hareket"
$PSQL -c "SELECT min(belge_tarihi)::text ilk, max(belge_tarihi)::text son, count(*) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid;"
$PSQL -c "SELECT to_char(date_trunc('month',belge_tarihi),'YYYY-MM') ay, count(*) hareket
          FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND belge_tarihi>=CURRENT_DATE-240
          GROUP BY 1 ORDER BY 1;"
echo "  ⚠ Son aylarda hareket düşüp sıfıra iniyorsa akış donmuş → geçmiş reconstruction o noktada durur."

hr "2. BUGÜNKÜ STOK DEĞERİ — ağırlıklı ort alış (bi_stok_hareket giris_tutari/giris) → ~235M mi?"
$PSQL -c "
WITH km AS (SELECT kalem_kodu, sum(giris_tutari) gt, sum(giris) g
              FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu)
SELECT round(sum(a.adet * (km.gt/km.g))/1e6,1) agirlikli_ort_m,
       count(*) FILTER (WHERE km.kalem_kodu IS NOT NULL) eslesen_kalem,
       count(*) FILTER (WHERE km.kalem_kodu IS NULL) maliyetsiz_kalem
  FROM bi_stok_anlik a LEFT JOIN km ON km.kalem_kodu=a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid AND a.adet>0;"
echo "  ⚠ ~235M bekleniyor (Sözleşme). maliyetsiz_kalem yüksekse eşleşme sorunu var."

hr "3. KARŞILAŞTIR — bi_maliyet_sku (hazır küp, tenant_id'SİZ) ne veriyor? (235 mi 274 mü)"
$PSQL -c "
SELECT round(sum(a.adet * m.birim_maliyet)/1e6,1) maliyet_sku_m,
       count(*) FILTER (WHERE m.sku IS NULL) eslesmeyern
  FROM bi_stok_anlik a LEFT JOIN bi_maliyet_sku m ON m.sku=a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid AND a.adet>0;"
echo "  ⚠ bi_maliyet_sku tenant_id'siz — çok-kiracılıda karışır; fonksiyonu bi_stok_hareket'ten kuracağım."

hr "4. ⚠ RECONSTRUCTION VIABLE Mİ — hareketten miktar (Σgiris−Σcikis) vs bi_stok_anlik.adet"
$PSQL -c "
WITH mov AS (SELECT kalem_kodu, sum(giris)-sum(cikis) qty FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY kalem_kodu)
SELECT round((SELECT sum(qty) FROM mov)) hareketten_toplam_adet,
       round((SELECT sum(adet) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid)) anlik_toplam_adet;"
echo "  ⚠ İkisi yakınsa hareket-bazlı reconstruction meşru (ACILIS dahil tüm giriş/çıkış yakalanmış)."

hr "5. DEPO KONTROL — anlik tek depo mu, hareket çok depo mu (transfer netlemesi)"
$PSQL -c "SELECT 'anlik' t, depo, count(*) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid GROUP BY 2
          UNION ALL SELECT 'hareket', depo, count(*) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 2 ORDER BY 1,3 DESC;" 2>&1 | head -20

hr "6. SAILUN ASTERİSK — hâlâ tek anomali mi (giriş/fatura oranı)"
$PSQL -c "
WITH km AS (SELECT kalem_kodu, marka, sum(giris_tutari) gt, sum(giris) g
              FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu, marka)
SELECT marka, round(sum(a.adet*(km.gt/km.g))/1e6,1) deger_m
  FROM bi_stok_anlik a JOIN km ON km.kalem_kodu=a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid AND a.adet>0 GROUP BY 1 ORDER BY 2 DESC NULLS LAST LIMIT 8;"

hr "BITTI — değer + reconstruction viable mi görüldü. Sağlamsa stok fonksiyonu + backfill kurulur."
