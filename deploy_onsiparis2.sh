#!/usr/bin/env bash
# ONSIPARIS_V2 — ebat eslestirmesi kalem_kodu uzerinden + maliyet kapsami gorunur.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

grep -q "ONSIPARIS_V1" server_container.mjs || { echo "❌ DUR: V1 yok"; exit 1; }

echo "############ 1) ⚠ ONCE OLC: regex ebat ne kadar yanlisti? ############"
$PSQL -c "
WITH regex_ebat AS (
  SELECT kalem_kodu,
         COALESCE(NULLIF(regexp_replace(kalem_tanimi,'^([0-9]+[/.][0-9]*[A-Z]*R?[0-9.]+C?).*\$','\\1'), kalem_tanimi),'') AS ebat_regex
    FROM bi_stok_anlik WHERE tenant_id='$TEN'::uuid AND adet>0),
erp_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat AS ebat_erp
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat IS NOT NULL AND ebat<>''
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN e.ebat_erp IS NULL THEN '❓ satista hic gecmemis (yeni SKU)'
            WHEN r.ebat_regex = e.ebat_erp THEN '✅ REGEX TUTTU'
            ELSE '❌ REGEX TUTMADI' END AS durum,
       count(*) AS sku,
       round(100.0*count(*)/sum(count(*)) OVER (),1) AS pct
  FROM regex_ebat r LEFT JOIN erp_ebat e ON e.kalem_kodu=r.kalem_kodu
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ^ '❌ REGEX TUTMADI' orani = V1'in ebat bazinda ne kadar YANLIS oldugu."

echo
echo "   -- ornek: regex ne diyor, ERP ne diyor? --"
$PSQL -c "
WITH r AS (
  SELECT kalem_kodu, kalem_tanimi, adet,
         COALESCE(NULLIF(regexp_replace(kalem_tanimi,'^([0-9]+[/.][0-9]*[A-Z]*R?[0-9.]+C?).*\$','\\1'), kalem_tanimi),'') AS ebat_regex
    FROM bi_stok_anlik WHERE tenant_id='$TEN'::uuid AND adet>0 AND sezon ILIKE '%KIS%'),
e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT left(r.kalem_tanimi,32) AS kalem, r.adet,
       r.ebat_regex AS REGEX_dedi, e.ebat AS ERP_diyor
  FROM r JOIN e ON e.kalem_kodu=r.kalem_kodu
 WHERE r.ebat_regex <> e.ebat
 ORDER BY r.adet DESC LIMIT 8;"

echo
echo "############ 2) YAMA ############"
if grep -q "ONSIPARIS_V2" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_onsip2
  python3 patch_onsiparis2.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_onsip2 server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_onsip2 server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) SQL DOGRULAMA ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN'::text AND ebat IS NOT NULL AND ebat<>''
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT ke.ebat, SUM(s.adet) mevcut,
       SUM(s.adet*m.maliyet)/NULLIF(SUM(s.adet) FILTER (WHERE m.maliyet IS NOT NULL),0) birim,
       SUM(s.adet) FILTER (WHERE m.maliyet IS NULL) maliyetsiz
  FROM bi_stok_anlik s JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
  LEFT JOIN son_maliyet m ON m.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%'
 GROUP BY 1;" >/dev/null \
 && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_onsip2 server_container.mjs; exit 1; }

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ⚠⚠ DUZELTILMIS LISTE — ebat kalem_kodu ile eslesti ############"
$PSQL -c "
WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
bayili AS (
  SELECT ebat, SUM(miktar)/2.0 s FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%' AND ebat<>''
     AND ((fatura_tarihi >= DATE '2021-10-01' AND fatura_tarihi < DATE '2022-02-01')
       OR (fatura_tarihi >= DATE '2022-10-01' AND fatura_tarihi < DATE '2023-02-01'))
   GROUP BY 1),
guncel AS (
  SELECT ebat, SUM(miktar) s FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%' AND ebat<>''
     AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
   GROUP BY 1),
pay AS (
  SELECT COALESCE(b.ebat,g.ebat) ebat,
         (COALESCE(b.s,0)*0.6+COALESCE(g.s,0)*0.4) w
    FROM bayili b FULL JOIN guncel g ON g.ebat=b.ebat),
oran AS (SELECT ebat, w/NULLIF(SUM(w) OVER (),0) o FROM pay WHERE w>0),
stok AS (
  SELECT ke.ebat, SUM(s.adet) mevcut,
         SUM(s.adet*m.maliyet)/NULLIF(SUM(s.adet) FILTER (WHERE m.maliyet IS NOT NULL),0) birim
    FROM bi_stok_anlik s JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
    LEFT JOIN son_maliyet m ON m.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%'
   GROUP BY 1),
em AS (
  SELECT sf.ebat, AVG(m.maliyet) maliyet FROM bi_satis_faturalari sf
    JOIN son_maliyet m ON m.kalem_kodu=sf.kalem_kodu
   WHERE sf.tenant_id='$TEN' AND sf.grup_adi LIKE 'LASTIK%'
     AND sf.kategori ILIKE '%KIS%' AND sf.ebat<>''
     AND sf.fatura_tarihi >= CURRENT_DATE-730 GROUP BY 1)
SELECT o.ebat, round(o.o*100,1) AS talep_pct,
       round(32000*o.o) AS hedef,
       COALESCE(round(st.mevcut),0) AS mevcut,
       GREATEST(round(32000*o.o)-COALESCE(st.mevcut,0),0) AS EKSIK,
       round(COALESCE(st.birim, em.maliyet)) AS birim_TL,
       CASE WHEN st.birim IS NOT NULL THEN 'stok'
            WHEN em.maliyet IS NOT NULL THEN 'ebat_ort'
            ELSE '❌ MALIYET YOK' END AS kaynak,
       round(GREATEST(round(32000*o.o)-COALESCE(st.mevcut,0),0)*COALESCE(st.birim,em.maliyet)/1e6,2) AS tutar_MTL
  FROM oran o LEFT JOIN stok st ON st.ebat=o.ebat LEFT JOIN em ON em.ebat=o.ebat
 WHERE o.o > 0.005 ORDER BY o.o DESC LIMIT 20;"

echo
echo "############ 6) TOPLAM — duzeltilmis ############"
$PSQL -c "
WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (SELECT SUM(s.adet) mevcut,
                SUM(s.adet*m.maliyet)/NULLIF(SUM(s.adet) FILTER (WHERE m.maliyet IS NOT NULL),0) birim,
                SUM(s.adet) FILTER (WHERE m.maliyet IS NULL) maliyetsiz
           FROM bi_stok_anlik s LEFT JOIN son_maliyet m ON m.kalem_kodu=s.kalem_kodu
          WHERE s.tenant_id='$TEN'::uuid AND s.sezon ILIKE '%KIS%' AND s.adet>0)
SELECT sen.ad, sen.hedef, round(stok.mevcut) AS mevcut,
       round(100.0*stok.mevcut/sen.hedef) AS karsilama_pct,
       sen.hedef-round(stok.mevcut) AS EKSIK,
       round((sen.hedef-stok.mevcut)*stok.birim/1e6) AS BAGLANACAK_MTL,
       round(stok.maliyetsiz) AS maliyeti_bilinmeyen_adet
  FROM stok, (VALUES ('temkinli',25000),('baz',32000),('iyimser',40000)) sen(ad,hedef)
 ORDER BY sen.hedef;"
echo "  ⚠ 'maliyeti_bilinmeyen_adet' > 0 ise tutar BU KADAR EKSIK. Sifir yazip gizlemiyoruz."

git add -A && git commit -q -m "fix(sezon): ONSIPARIS_V2 — ebat artik kalem_kodu uzerinden ERP'nin kendi alanindan (V1 kalem_tanimi'ndan REGEX ile cikariyordu, satis tablosuyla tutmuyordu -> mevcut stok ve eksik hesabi YANLISTI). Maliyeti eslesmeyen satirlar artik SIFIR yazilip gizlenmiyor, 'MALIYET_YOK' bayragiyla ayri raporlaniyor." && echo "  COMMITTED"
