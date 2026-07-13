#!/usr/bin/env bash
# ONSIPARIS_V5 — kalip genisletildi. ⚠ KAPI HALA %98.
#
# V4 KAPIDAN GECEMEDI: %94,8 (esik %98). Yama UYGULANMADI. Kapi CALISTI.
#
# ⚠ KALAN HATALAR TEK BIR AILEYE AITTI: IS MAKINESI + CAPRAZ LASTIK
#     440/80-28 · 29.5R25 · 14.00-24 · 10.00-20 · 8.5R17.5 · 26.5R25
#
#   Kalibimda UC YANLIS VARSAYIM vardi:
#     1) 'R' bekliyordum       -> capraz lastikte TIRE var (440/80-28)
#     2) Ondalik 2 hane        -> 29.5 TEK haneli
#     3) Basta en az 2 rakam   -> 8.5R17.5 TEK rakamla basliyor
#
#   Binek lastigine bakip kural yazmisim; ticari/OTR'yi gormemisim.
#   Bugun 8. kez ayni ders: KALIBI TUM VERIYE BAKMADAN YAZMA.
#
# YENI KALIP:
#   ^([0-9]{1,3}(\.[0-9]{1,2})?(/[0-9]{2,3}(\.[0-9])?)?[A-Z]*[R-][0-9]{2}(\.[0-9])?C?)
#     245/40R18   -> 245 /40 R 18        ✓
#     185R14C     -> 185 R 14 C          ✓
#     29.5R25     -> 29 .5 R 25          ✓
#     440/80-28   -> 440 /80 - 28        ✓  (tire!)
#     14.00-24    -> 14 .00 - 24         ✓
#     8.5R17.5    -> 8 .5 R 17 .5        ✓
#     225/45ZR17  -> [A-Z]* Z'yi yakalar ✓  (sonra ZR->R)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
KALIP='^([0-9]{1,3}(\.[0-9]{1,2})?(/[0-9]{2,3}(\.[0-9])?)?[A-Z]*[R-][0-9]{2}(\.[0-9])?C?)'

echo "############ 1) ⚠⚠ KAPI — yeni kalip ERP ile tutuyor mu? ############"
echo "   V3 (ham ilk kelime) : %92,7  ❌"
echo "   V4 (Z + bosluk)     : %94,8  ❌  (is makinesi/capraz kacti)"
echo "   V5 (tire + tek hane): ?"
ORAN=$($PSQL -tA -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
n AS (
  SELECT e.ebat AS erp,
         NULLIF(replace(substring(replace(upper(s.kalem_tanimi),' ','') from '$KALIP'),'ZR','R'),'') AS turetilmis
    FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT round(100.0*count(*) FILTER (WHERE turetilmis = erp)/NULLIF(count(*),0),1) FROM n;")
echo "  ✅ TUTMA ORANI: %$ORAN"

$PSQL -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
n AS (
  SELECT s.kalem_tanimi, s.adet, e.ebat AS erp,
         NULLIF(replace(substring(replace(upper(s.kalem_tanimi),' ','') from '$KALIP'),'ZR','R'),'') AS turetilmis
    FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT CASE WHEN turetilmis = erp THEN '✅ TUTTU'
            WHEN turetilmis IS NULL THEN '❓ KALIP YAKALAMADI'
            ELSE '❌ FARKLI' END AS durum,
       count(*) AS sku, round(sum(adet)) AS adet,
       round(100.0*count(*)/sum(count(*)) OVER (),1) AS pct
  FROM n GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "   -- HALA TUTMAYANLAR --"
$PSQL -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
n AS (
  SELECT s.kalem_tanimi, s.adet, e.ebat AS erp,
         NULLIF(replace(substring(replace(upper(s.kalem_tanimi),' ','') from '$KALIP'),'ZR','R'),'') AS turetilmis
    FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT left(kalem_tanimi,38) AS kalem, COALESCE(turetilmis,'(yakalamadi)') AS turetilmis, erp, adet
  FROM n WHERE turetilmis IS DISTINCT FROM erp ORDER BY adet DESC LIMIT 10;"

if (( $(echo "$ORAN < 98" | bc -l) )); then
  echo
  echo "❌ KAPI KAPALI: %$ORAN < %98. YAMA UYGULANMADI."
  echo "   Uydurmaktansa BOS birakiriz. Kalan hatalari yukarida gor."
  exit 1
fi
echo "  ✅ KAPI ACIK (>= %98)"

echo
echo "############ 2) YAMA — kalibi V4 dosyasinda guncelle, sonra uygula ############"
python3 - <<'PY'
import io
p = "patch_onsiparis4.py"
s = io.open(p, encoding="utf-8").read()
eski = r"'^([0-9]{2,3}(/[0-9]{2,3})?(\\\\.[0-9]{2})?Z?R[0-9]{2}(\\\\.[0-9])?C?)'"
yeni = r"'^([0-9]{1,3}(\\\\.[0-9]{1,2})?(/[0-9]{2,3}(\\\\.[0-9])?)?[A-Z]*[R-][0-9]{2}(\\\\.[0-9])?C?)'"
n = s.count(eski)
assert n == 2, "ABORT: kalip %d kez bulundu (2 bekleniyordu)" % n
s = s.replace(eski, yeni)
io.open(p, "w", encoding="utf-8").write(s)
print("  OK: kalip guncellendi (%d yer)" % n)
PY

if grep -q "ONSIPARIS_V4" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_onsip5
  python3 patch_onsiparis4.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_onsip5 server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_onsip5 server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 4) KIS STOGU — ebat kapsami ############"
$PSQL -c "
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN ke.ebat IS NOT NULL THEN '1️⃣ ERP ebati'
            WHEN NULLIF(replace(substring(replace(upper(s.kalem_tanimi),' ','') from '$KALIP'),'ZR','R'),'')
                 IS NOT NULL THEN '3️⃣ turetilmis (kanitlanmis kalip)'
            ELSE '❌ ESLESMIYOR' END AS kademe,
       count(*) AS sku, round(sum(s.adet)) AS kis_adet
  FROM bi_stok_anlik s LEFT JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%'
 GROUP BY 1 ORDER BY 3 DESC;"

git add -A && git commit -q -m "fix(sezon): ONSIPARIS_V5 — ebat kalibi is makinesi/capraz lastigi kaciriyordu (440/80-28, 29.5R25, 14.00-24, 8.5R17.5). Uc yanlis varsayim: 'R' zorunlu (tire de olabilir), ondalik 2 hane (tek de olabilir), basta 2 rakam (tek de olabilir). Binek lastigine bakip kural yazilmis, ticari/OTR gorulmemis. V4 kapidan gecememisti (%94,8 < %98) ve yama UYGULANMAMISTI — kapi calisti." && echo "  COMMITTED"
