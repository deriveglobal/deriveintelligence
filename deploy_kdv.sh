#!/usr/bin/env bash
# KDV_V1 — kdv_haric bayragi + marka sizmasi.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ HASAR — su an ekran ne gosteriyor? ############"
$PSQL -c "
WITH liste AS (
  SELECT u.marka, u.kategori, u.kdv_haric, k.ebat, k.liste_fiyati
    FROM bi_fiyat_listesi_kalemler k
    JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
   WHERE k.tenant_id='$TEN'::uuid AND u.aktif AND k.liste_fiyati>0),
isk AS (
  SELECT upper(marka) AS marka,
         (1-(1-baz_iskonto1/100.0)*(1-baz_iskonto2/100.0)*(1-ds/100.0)*(1-skala_primi/100.0)) AS ind
    FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid AND aktif AND arac_tipi='BINEK'
   GROUP BY 1,2)
SELECT l.marka, l.kdv_haric,
       l.ebat,
       round(l.liste_fiyati) AS kayitli_liste,
       round(l.liste_fiyati * (1-i.ind))                        AS EKRANDAKI_MALIYET,
       round(CASE WHEN l.kdv_haric THEN l.liste_fiyati
                  ELSE l.liste_fiyati/1.20 END * (1-i.ind))     AS DOGRU_MALIYET,
       round(100.0*(l.liste_fiyati*(1-i.ind))
             / NULLIF(CASE WHEN l.kdv_haric THEN l.liste_fiyati
                           ELSE l.liste_fiyati/1.20 END*(1-i.ind),0) - 100) AS SISME_PCT
  FROM liste l JOIN isk i ON i.marka=upper(l.marka)
 WHERE l.ebat IN ('205/55R16','185/65R15','195/65R15')
 ORDER BY l.marka, l.ebat LIMIT 14;"
echo "  ^ SISME_PCT = 20 olan markalarda maliyet %20 SISIK -> marj 20 PUAN DUSUK."
echo "    0 olanlar dogru. AYNI EKRANDA IKI FARKLI TEMEL."

echo
echo "############ 2) ⚠ MARKA SIZMASI — kac ebatta baska markanin fiyati aliniyordu? ############"
$PSQL -c "
WITH satis_ebat AS (
  SELECT DISTINCT marka, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND ebat<>'' AND miktar>0
     AND fatura_tarihi >= CURRENT_DATE - 90
     AND upper(marka) IN ('LASSA','BRIDGESTONE','DAYTON','CONTINENTAL','BARUM','MATADOR')),
kendi AS (
  SELECT DISTINCT upper(u.marka) AS marka, regexp_replace(upper(k.ebat),'\s+','','g') AS ebat
    FROM bi_fiyat_listesi_kalemler k JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
   WHERE k.tenant_id='$TEN'::uuid AND u.aktif AND k.liste_fiyati>0),
baska AS (
  SELECT DISTINCT regexp_replace(upper(k.ebat),'\s+','','g') AS ebat
    FROM bi_fiyat_listesi_kalemler k JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
   WHERE k.tenant_id='$TEN'::uuid AND u.aktif AND k.liste_fiyati>0)
SELECT CASE WHEN ke.marka IS NOT NULL THEN '✅ kendi markasinin listesi var'
            WHEN b.ebat IS NOT NULL   THEN '❌ BASKA MARKANIN fiyati aliniyordu'
            ELSE '⚪ hic liste yok (son alisa duser)' END AS durum,
       count(*) AS marka_ebat
  FROM satis_ebat se
  LEFT JOIN kendi ke ON ke.marka=upper(se.marka)
                    AND ke.ebat=regexp_replace(upper(se.ebat),'\s+','','g')
  LEFT JOIN baska b ON b.ebat=regexp_replace(upper(se.ebat),'\s+','','g')
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ^ '❌' olanlarda LASSA teklifine CONTINENTAL fiyati uygulaniyordu. SESSIZCE."

echo
echo "############ 3) YAMA ############"
if grep -q "KDV_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_kdv
  python3 patch_kdv.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_kdv server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_kdv server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 4) SQL DOGRULAMA ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT k2.liste_fiyati, u.kdv_haric, u.marka AS liste_marka
  FROM bi_fiyat_listesi_kalemler k2
  JOIN bi_fiyat_listesi_uploads u ON u.id = k2.upload_id
 WHERE k2.tenant_id='$TEN'::uuid AND u.aktif = true AND k2.liste_fiyati IS NOT NULL
   AND regexp_replace(upper(k2.ebat),'\s+','','g') = regexp_replace(upper('205/55R16'),'\s+','','g')
   AND upper(u.marka) = upper('LASSA')
 ORDER BY u.liste_tarihi DESC LIMIT 1;" >/dev/null \
 && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_kdv server_container.mjs; exit 1; }

echo
echo "############ 5) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 6) ⚠ ETKI — bayilik marji nasil degisti? ############"
echo "   (Bugun olctugumuz: bayilik medyan marj %8 — BRUT, prim haric, KDV HATALI)"
$PSQL -c "
WITH liste AS (
  SELECT upper(u.marka) AS marka,
         regexp_replace(upper(k.ebat),'\s+','','g') AS ebat,
         CASE WHEN u.kdv_haric THEN k.liste_fiyati ELSE k.liste_fiyati/1.20 END AS liste_haric,
         k.liste_fiyati AS liste_ham, u.kdv_haric
    FROM bi_fiyat_listesi_kalemler k JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
   WHERE k.tenant_id='$TEN'::uuid AND u.aktif AND k.liste_fiyati>0),
isk AS (
  SELECT upper(marka) AS marka,
         max(1-(1-baz_iskonto1/100.0)*(1-baz_iskonto2/100.0)*(1-ds/100.0)*(1-skala_primi/100.0)) AS ind
    FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid AND aktif GROUP BY 1),
sat AS (
  SELECT upper(f.marka) AS marka, regexp_replace(upper(f.ebat),'\s+','','g') AS ebat,
         SUM(f.miktar*f.birim_fiyat)/NULLIF(SUM(f.miktar),0) AS satis, SUM(f.miktar) AS adet
    FROM bi_satis_faturalari f
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0 AND f.birim_fiyat>0
     AND f.fatura_tarihi >= CURRENT_DATE - 90
   GROUP BY 1,2)
SELECT l.kdv_haric AS liste_kdv_haric_mi,
       count(*) AS urun,
       round(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY 100.0*(s.satis - l.liste_ham*(1-i.ind))/NULLIF(s.satis,0))::numeric) AS ESKI_medyan_marj,
       round(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY 100.0*(s.satis - l.liste_haric*(1-i.ind))/NULLIF(s.satis,0))::numeric) AS YENI_medyan_marj
  FROM liste l
  JOIN isk i ON i.marka=l.marka
  JOIN sat s ON s.marka=l.marka AND s.ebat=l.ebat
 GROUP BY 1 ORDER BY 1;"
echo "  ^ kdv_haric=f (BRISA) satirinda ESKI vs YENI farki = duzeltilen hata."
echo "    kdv_haric=t (CONTI) satirinda fark OLMAMALI (zaten dogruydu)."

git add -A && git commit -q -m "fix(teklif): KDV_V1 — iki sessiz hata. (1) bi_fiyat_listesi_uploads.kdv_haric bayragi VAR ve dogru doldurulmus (Brisa=KDV dahil, Conti=KDV haric) ama teklif ekraninin marj sorgusu bunu HIC OKUMUYORDU -> Brisa'da maliyet %20 sisik, marj 20 puan dusuk, GM iyi teklifleri reddediyordu. (2) Sorgunun WHERE'inde MARKA FILTRESI YOKTU; ORDER BY sadece tercih ediyordu -> LASSA teklifine CONTINENTAL liste fiyati uygulanabiliyordu. Artik marka eslesmesi ZORUNLU." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_kdv server_container.mjs && docker cp server_container.mjs krb-assessment:/app/server.mjs && docker restart krb-assessment"
