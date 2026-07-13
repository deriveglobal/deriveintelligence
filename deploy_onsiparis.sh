#!/usr/bin/env bash
# ONSIPARIS_V1 — yeni /api/bi/sezon/onsiparis ucu.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) YAMA ############"
if grep -q "ONSIPARIS_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_onsip
  python3 patch_onsiparis.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_onsip server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_onsip server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 2) ⚠ SQL'i POSTGRES'E DOGRULAT ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
bayili AS (
  SELECT ebat, SUM(miktar)/2.0 AS sezon_ort FROM bi_satis_faturalari
   WHERE tenant_id='$TEN'::text AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%' AND ebat <> ''
     AND ((fatura_tarihi >= DATE '2021-10-01' AND fatura_tarihi < DATE '2022-02-01')
       OR (fatura_tarihi >= DATE '2022-10-01' AND fatura_tarihi < DATE '2023-02-01'))
   GROUP BY 1),
guncel AS (
  SELECT ebat, SUM(miktar) AS sezon_adet FROM bi_satis_faturalari
   WHERE tenant_id='$TEN'::text AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%' AND ebat <> ''
     AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
   GROUP BY 1),
harman AS (
  SELECT COALESCE(b.ebat,g.ebat) AS ebat,
         COALESCE(b.sezon_ort,0)*0.6 + COALESCE(g.sezon_adet,0)*0.4 AS agirlik
    FROM bayili b FULL JOIN guncel g ON g.ebat=b.ebat),
pay AS (SELECT ebat, agirlik, agirlik/NULLIF(SUM(agirlik) OVER (),0) AS oran
          FROM harman WHERE agirlik>0)
SELECT ebat, ROUND(oran*100,2), ROUND(32000*oran) FROM pay WHERE oran>0.001 ORDER BY oran DESC LIMIT 60;" >/dev/null \
 && echo "  SQL_OK: talep" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_onsip server_container.mjs; exit 1; }

echo
echo "############ 3) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 4) ⚠ MODELIN CIKTISI — ebat bazinda on siparis (baz senaryo: 32.000) ############"
$PSQL -c "
WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
bayili AS (
  SELECT ebat, SUM(miktar)/2.0 AS s FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%' AND ebat<>''
     AND ((fatura_tarihi >= DATE '2021-10-01' AND fatura_tarihi < DATE '2022-02-01')
       OR (fatura_tarihi >= DATE '2022-10-01' AND fatura_tarihi < DATE '2023-02-01'))
   GROUP BY 1),
guncel AS (
  SELECT ebat, SUM(miktar) AS s FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%' AND ebat<>''
     AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
   GROUP BY 1),
harman AS (
  SELECT COALESCE(b.ebat,g.ebat) AS ebat,
         COALESCE(b.s,0)*0.6 + COALESCE(g.s,0)*0.4 AS agirlik
    FROM bayili b FULL JOIN guncel g ON g.ebat=b.ebat),
pay AS (SELECT ebat, agirlik/NULLIF(SUM(agirlik) OVER (),0) AS oran FROM harman WHERE agirlik>0),
stok AS (
  SELECT s.ebat, SUM(s.adet) AS mevcut,
         SUM(s.adet*m.maliyet)/NULLIF(SUM(s.adet),0) AS birim
    FROM (SELECT kalem_kodu, adet,
                 COALESCE(NULLIF(regexp_replace(kalem_tanimi,'^([0-9]+[/.][0-9]*[A-Z]*R?[0-9.]+C?).*$','\\1'), kalem_tanimi),'') AS ebat
            FROM bi_stok_anlik
           WHERE tenant_id='$TEN'::uuid AND adet>0 AND sezon ILIKE '%KIS%') s
    JOIN son_maliyet m ON m.kalem_kodu=s.kalem_kodu
   GROUP BY 1)
SELECT p.ebat,
       round(p.oran*100,1) AS talep_pay_pct,
       round(32000*p.oran) AS hedef,
       COALESCE(round(st.mevcut),0) AS mevcut,
       GREATEST(round(32000*p.oran) - COALESCE(st.mevcut,0),0) AS EKSIK,
       round(COALESCE(st.birim,0)) AS birim_TL,
       round(GREATEST(round(32000*p.oran)-COALESCE(st.mevcut,0),0)*COALESCE(st.birim,0)/1e6,2) AS tutar_MTL
  FROM pay p LEFT JOIN stok st ON st.ebat=p.ebat
 WHERE p.oran > 0.005
 ORDER BY p.oran DESC LIMIT 20;"

echo
echo "############ 5) ⚠ TOPLAM — bu kis ne kadar baglanmali? ############"
$PSQL -c "
WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (SELECT SUM(s.adet) mevcut, SUM(s.adet*m.maliyet)/NULLIF(SUM(s.adet),0) birim
           FROM bi_stok_anlik s JOIN son_maliyet m ON m.kalem_kodu=s.kalem_kodu
          WHERE s.tenant_id='$TEN'::uuid AND s.sezon ILIKE '%KIS%' AND s.adet>0)
SELECT sen.ad, sen.hedef,
       round(stok.mevcut) AS mevcut_stok,
       round(100.0*stok.mevcut/sen.hedef) AS karsilama_pct,
       sen.hedef - round(stok.mevcut) AS EKSIK_ADET,
       round((sen.hedef - stok.mevcut) * stok.birim / 1e6) AS BAGLANACAK_MTL
  FROM stok, (VALUES ('temkinli',25000),('baz',32000),('iyimser',40000)) AS sen(ad,hedef)
 ORDER BY sen.hedef;"
echo
echo "  ⚠ SENARYO SECIMI FATIH BILEN'IN KARARI. Model dayatmaz, uc secenegi gosterir."
echo "  ⚠ kesin_siparis_pct = 0.00 (tum markalarda). Doldurulmadan 'erken/bekle' denemez."
echo "     Ama karsilama %5 civari -> tukenme riski primden AGIR BASIYOR."

git add -A && git commit -q -m "feat(sezon): ONSIPARIS_V1 — /api/bi/sezon/onsiparis. Talep tahmini MARKA gecmisine degil KATEGORI toplamina dayaniyor (KRB 3 yil Brisa bayisi degildi; LASSA 2024=899 adet). Ebat dagilimi bayili donem %60 + son sezon %40. Uc senaryo (25K/32K/40K) — secim kullanicinin. Finansman esigi %7,1 (Brisa taksit takvimi, 65 gun). Eski /api/bi/orders/preorder donmus bi_stok_durumu okuyordu." && echo "  COMMITTED"
