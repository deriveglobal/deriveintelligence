#!/usr/bin/env bash
# TEKLIF_V2 dagitimi.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SEMA: teklife VADE alani ekle ############"
echo "  (Fatih'in 1. istegi: 'onay talebinde satis vadesi olsun, onaylayan gorsun')"
echo "  saha_teklif'te vade kolonu YOKTU — temsilci vade giremiyor, onaylayan goremiyordu."
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE saha_teklif       ADD COLUMN IF NOT EXISTS vade_gun  integer;
ALTER TABLE saha_teklif       ADD COLUMN IF NOT EXISTS vade_turu text;
ALTER TABLE saha_teklif_kalem ADD COLUMN IF NOT EXISTS vade_gun  integer;
SQL
echo "  ✅ vade_gun / vade_turu eklendi"

echo
echo "############ 2) YAMA ############"
if grep -q "TEKLIF_V2" server_container.mjs; then echo "  ZATEN YAMALI"; exit 0; fi
cp server_container.mjs server_container.mjs.bak_teklif
python3 patch_teklif.py server_container.mjs || {
  echo "❌ YAMA BASARISIZ — geri alindi"; cp server_container.mjs.bak_teklif server_container.mjs; exit 1; }

echo
echo "############ 3) KAPILAR ############"
node --check server_container.mjs || {
  echo "❌ NODE FAIL — geri alindi"; cp server_container.mjs.bak_teklif server_container.mjs; exit 1; }
echo "  NODE_OK"

echo
echo "############ 4) ⚠ SQL'I ONCE POSTGRES'E DOGRULAT ############"
echo "  (gecmis ders: node --check gecti ama SQL kolonu yoktu -> uygulama coktu)"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT COUNT(*)::int AS n,
  ROUND(MIN(birim_fiyat)) AS mn, ROUND(MAX(birim_fiyat)) AS mx,
  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS med,
  (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1] AS en_ucuz_musteri
 FROM bi_satis_faturalari
WHERE tenant_id='$TEN'::text AND ebat='205/55R16' AND upper(marka)=upper('LASSA')
  AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0
  AND fatura_tarihi >= date_trunc('year', CURRENT_DATE);" >/dev/null \
  && echo "  SQL_KENDI_SATIS_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_teklif server_container.mjs; exit 1; }

$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH sat AS (
  SELECT SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0) AS ag_fiyat,
         SUM(miktar*(vade_tarihi - fatura_tarihi))/NULLIF(SUM(miktar),0) AS ag_vade,
         SUM(miktar) AS adet
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN'::text AND kalem_kodu='X' AND birim_fiyat>0
     AND vade_tarihi IS NOT NULL AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)),
alis AS (
  SELECT SUM(miktar*birim_fiyat_kdv_haric)/NULLIF(SUM(miktar),0) AS ag_fiyat,
         SUM(miktar*vade_gun)/NULLIF(SUM(miktar),0) AS ag_vade, SUM(miktar) AS adet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND kalem_kodu='X' AND birim_fiyat_kdv_haric>0
     AND vade_gun IS NOT NULL AND fatura_tarihi >= date_trunc('year', CURRENT_DATE))
SELECT ROUND(sat.ag_fiyat), ROUND(alis.ag_fiyat) FROM sat, alis;" >/dev/null \
  && echo "  SQL_AGIRLIKLI_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_teklif server_container.mjs; exit 1; }

echo
echo "############ 5) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 6) CANLI ORNEK — onaylayan artik BUNU gorecek ############"
$PSQL -c "
WITH k AS (SELECT '205/55R16'::text AS ebat, 'LASSA'::text AS marka)
SELECT k.marka, k.ebat,
       ROUND(MIN(s.birim_fiyat))  AS min_TL,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY s.birim_fiyat)::numeric) AS medyan_TL,
       ROUND(MAX(s.birim_fiyat))  AS max_TL,
       (array_agg(s.musteri_adi ORDER BY s.birim_fiyat ASC))[1]  AS en_ucuza_ALAN,
       (array_agg(s.musteri_adi ORDER BY s.birim_fiyat DESC))[1] AS en_pahaliya_ALAN
  FROM bi_satis_faturalari s, k
 WHERE s.tenant_id='$TEN' AND s.ebat=k.ebat AND upper(s.marka)=upper(k.marka)
   AND s.birim_fiyat>0 AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 GROUP BY 1,2;"

git add -A && git commit -q -m "feat(teklif): TEKLIF_V2 — onay ekraninda min/medyan/max satis + kim aldi, agirlikli alis/satis vadesi, IKAME (fiyatlama) ve BATIK (gerceklesen) maliyet ayri ayri; teklife vade alani" && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_teklif server_container.mjs && docker cp ... && docker restart"
