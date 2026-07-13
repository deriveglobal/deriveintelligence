#!/usr/bin/env bash
# IADE_V1 — iade satirlari (miktar<0) fiyat/maliyet analizinden cikarilsin.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) IADE HACMI — ne kadar sey karisiyordu? ############"
$PSQL -c "
SELECT 'SATIS iadesi' AS tur, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS tutar_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar < 0
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
UNION ALL
SELECT 'ALIS iadesi', count(*), round(sum(satir_kdv_haric)/1e6,2)
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND miktar < 0
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE);"

echo
echo "   -- ⚠ IADEDEN MALIYET TURETILEN kalem var mi? (en sinsi hali) --"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, miktar, birim_fiyat_kdv_haric AS f, fatura_tarihi
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT count(*) FILTER (WHERE miktar < 0) AS iadeden_maliyet_alan_kalem,
       count(*) AS toplam_kalem
  FROM son;"
echo "  ^ >0 ise: o kalemlerde IKAME MALIYETI bir IADE faturasindan geliyordu."

echo
echo "############ 2) YAMA ############"
if grep -q "IADE_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_iade
  python3 patch_iade.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_iade server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_iade server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) SQL'i POSTGRES'E DOGRULAT ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT COUNT(*)::int AS n, SUM(miktar)::numeric AS adet,
  ROUND(MIN(birim_fiyat)) AS mn, ROUND(MAX(birim_fiyat)) AS mx,
  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS med
 FROM bi_satis_faturalari
 WHERE tenant_id='$TEN'::text AND ebat='205/55R16' AND upper(marka)=upper('LASSA')
   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 AND miktar > 0
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE);" >/dev/null \
 && echo "  SQL_OK: kendi_satis" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_iade server_container.mjs; exit 1; }

$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT birim_fiyat_kdv_haric AS f FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND kalem_kodu='X' AND birim_fiyat_kdv_haric > 0 AND miktar > 0
 ORDER BY fatura_tarihi DESC LIMIT 1;" >/dev/null \
 && echo "  SQL_OK: son_alis" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_iade server_container.mjs; exit 1; }

echo
echo "############ 4) ⚠ KALAN SORGULAR — miktar filtresi olmayan var mi? ############"
grep -n "bi_satis_faturalari" server_container.mjs | grep -vi "miktar" | head -8
echo "  ^ Bunlar RAPOR sorgulari olabilir (iade ciroya DAHIL olmali — dogru)."
echo "    Sadece FIYAT/MALIYET turetenlerde miktar>0 gerekiyor. Kontrol et."

echo
echo "############ 5) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 6) ETKI — hangi urunlerde aralik degisti? ############"
$PSQL -c "
WITH eski AS (
  SELECT marka, ebat, min(birim_fiyat) AS mn, max(birim_fiyat) AS mx, count(*) AS n
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0
     AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   GROUP BY 1,2),
yeni AS (
  SELECT marka, ebat, min(birim_fiyat) AS mn, max(birim_fiyat) AS mx, count(*) AS n
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 AND miktar > 0
     AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   GROUP BY 1,2)
SELECT e.marka, e.ebat, e.n AS eski_satir, y.n AS yeni_satir,
       round(e.mn) AS eski_min, round(y.mn) AS yeni_min,
       round(e.mx) AS eski_max, round(y.mx) AS yeni_max
  FROM eski e JOIN yeni y ON y.marka=e.marka AND y.ebat=e.ebat
 WHERE e.n <> y.n
 ORDER BY (e.n - y.n) DESC LIMIT 10;"
echo "  ^ Bu urunlerde min/medyan/maks araligi artik IADE ICERMIYOR."

git add -A && git commit -q -m "fix(teklif): IADE_V1 — miktar<0 (iade/alacak dekontu) satirlari fiyat ve maliyet turetmeden cikarildi. Agirlikli ortalamada negatif miktar ters isaretli agirlik verip sonucu SESSIZCE kaydiriyordu; min/maks araligina ve 'en ucuz musteri'ye iade karisiyordu; ikame maliyeti bir iade faturasindan gelebiliyordu. Ciro raporlari DEGISMEDI (iade ciroda kalmali)." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_iade server_container.mjs && docker cp server_container.mjs krb-assessment:/app/server.mjs && docker restart krb-assessment"
