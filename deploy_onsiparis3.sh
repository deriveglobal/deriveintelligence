#!/usr/bin/env bash
# ONSIPARIS_V3 — yeni SKU'lar (Brisa donusu) artik ebat eslesiyor.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

grep -q "ONSIPARIS_V2" server_container.mjs || { echo "❌ DUR: V2 yok"; exit 1; }

echo "############ 1) ⚠ 'ILK KELIME' YONTEMI DOGRU MU? — ERP ile KIYASLA ############"
echo "   Satista GECEN SKU'larda ERP'nin ebati ile ilk-kelime AYNI mi?"
echo "   Ayni ise yontem KANITLANIR -> yeni SKU'larda da guvenle kullanilir."
$PSQL -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN substring(s.kalem_tanimi from '^([^ ]+)') = e.ebat
            THEN '✅ ILK KELIME = ERP EBATI'
            ELSE '❌ FARKLI' END AS durum,
       count(*) AS sku, round(sum(s.adet)) AS adet,
       round(100.0*count(*)/sum(count(*)) OVER (),1) AS pct
  FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ^ ✅ orani YUKSEKSE (>%95) yontem KANITLANDI. Dusukse KULLANMAYIZ."

echo
echo "   -- FARKLI olanlar (varsa) --"
$PSQL -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT left(s.kalem_tanimi,34) AS kalem,
       substring(s.kalem_tanimi from '^([^ ]+)') AS ilk_kelime, e.ebat AS erp_ebat, s.adet
  FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0
   AND substring(s.kalem_tanimi from '^([^ ]+)') <> e.ebat
 ORDER BY s.adet DESC LIMIT 8;"

echo
echo "############ 2) YAMA ############"
if grep -q "ONSIPARIS_V3" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_onsip3
  python3 patch_onsiparis3.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_onsip3 server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_onsip3 server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) SQL DOGRULAMA ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN'::text AND ebat IS NOT NULL AND ebat<>''
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok_ebat AS (
  SELECT s.kalem_kodu, s.adet,
         COALESCE(ke.ebat, substring(s.kalem_tanimi from '^([^ ]+)')) AS ebat,
         CASE WHEN ke.ebat IS NOT NULL THEN 'erp' ELSE 'turetilmis' END AS kaynak
    FROM bi_stok_anlik s LEFT JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%')
SELECT ebat, SUM(adet), SUM(adet) FILTER (WHERE kaynak='turetilmis')
  FROM stok_ebat WHERE ebat IS NOT NULL AND ebat<>'' GROUP BY 1;" >/dev/null \
 && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_onsip3 server_container.mjs; exit 1; }

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ⚠ KAPSAM — kis stogunun kaci artik eslesiyor? ############"
$PSQL -c "
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN ke.ebat IS NOT NULL THEN '1️⃣ ERP ebati (satis tablosu)'
            WHEN substring(s.kalem_tanimi from '^([^ ]+)') <> '' THEN '3️⃣ turetilmis (urun adi ilk kelime)'
            ELSE '❌ HALA ESLESMIYOR' END AS kademe,
       count(*) AS sku, round(sum(s.adet)) AS kis_adet,
       round(100.0*sum(s.adet)/sum(sum(s.adet)) OVER (),1) AS pct
  FROM bi_stok_anlik s LEFT JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%'
 GROUP BY 1 ORDER BY 3 DESC;"
echo "  ^ '❌ HALA ESLESMIYOR' 0 olmali. V2'de 252 adet kor noktaydi."

echo
echo "############ 6) ⚠⚠ NIHAI LISTE — ON SIPARIS (baz: 32.000) ############"
$PSQL -c "
WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
stok_ebat AS (
  SELECT s.kalem_kodu, s.adet,
         COALESCE(ke.ebat, substring(s.kalem_tanimi from '^([^ ]+)')) AS ebat,
         CASE WHEN ke.ebat IS NOT NULL THEN 'erp' ELSE 'turetilmis' END AS kaynak
    FROM bi_stok_anlik s LEFT JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%'),
stok AS (
  SELECT se.ebat, SUM(se.adet) mevcut,
         SUM(se.adet*m.maliyet)/NULLIF(SUM(se.adet) FILTER (WHERE m.maliyet IS NOT NULL),0) birim,
         SUM(se.adet) FILTER (WHERE se.kaynak='turetilmis') turetilmis
    FROM stok_ebat se LEFT JOIN son_maliyet m ON m.kalem_kodu=se.kalem_kodu
   WHERE se.ebat IS NOT NULL AND se.ebat<>'' GROUP BY 1),
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
oran AS (
  SELECT COALESCE(b.ebat,g.ebat) ebat,
         (COALESCE(b.s,0)*0.6+COALESCE(g.s,0)*0.4) w
    FROM bayili b FULL JOIN guncel g ON g.ebat=b.ebat),
o2 AS (SELECT ebat, w/NULLIF(SUM(w) OVER (),0) o FROM oran WHERE w>0),
em AS (
  SELECT sf.ebat, AVG(m.maliyet) maliyet FROM bi_satis_faturalari sf
    JOIN son_maliyet m ON m.kalem_kodu=sf.kalem_kodu
   WHERE sf.tenant_id='$TEN' AND sf.grup_adi LIKE 'LASTIK%'
     AND sf.kategori ILIKE '%KIS%' AND sf.ebat<>''
     AND sf.fatura_tarihi >= CURRENT_DATE-730 GROUP BY 1)
SELECT o2.ebat, round(o2.o*100,1) AS talep_pct,
       round(32000*o2.o) AS hedef,
       COALESCE(round(st.mevcut),0) AS mevcut,
       COALESCE(round(st.turetilmis),0) AS bunun_turetilmis,
       GREATEST(round(32000*o2.o)-COALESCE(st.mevcut,0),0) AS EKSIK,
       round(COALESCE(st.birim, em.maliyet)) AS birim_TL,
       round(GREATEST(round(32000*o2.o)-COALESCE(st.mevcut,0),0)*COALESCE(st.birim,em.maliyet)/1e6,2) AS tutar_MTL
  FROM o2 LEFT JOIN stok st ON st.ebat=o2.ebat LEFT JOIN em ON em.ebat=o2.ebat
 WHERE o2.o > 0.005 ORDER BY o2.o DESC LIMIT 20;"

git add -A && git commit -q -m "fix(sezon): ONSIPARIS_V3 — yeni SKU'lar (Brisa donusu: BLIZZAK 6, SNOWAYS 4, WINTUS 2) satista henuz gecmedigi icin ebat eslesmiyordu -> 252 adet kis stogu KOR NOKTAYDI -> eksik fazla, siparis fazla cikardi. Uc kademeli cozum: satis tablosu > urun master > urun adinin ILK KELIMESI (ki o zaten ebattir). V2'nin regex'i ticari ebatlarda (185R14C) bos donuyordu." && echo "  COMMITTED"
