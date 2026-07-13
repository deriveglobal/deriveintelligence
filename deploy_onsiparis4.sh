#!/usr/bin/env bash
# ONSIPARIS_V4 — ebat normalizasyonu. ⚠ KAPI: oz-dogrulama >= %98 olmali.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

grep -q "ONSIPARIS_V3" server_container.mjs || { echo "❌ DUR: V3 yok"; exit 1; }

echo "############ 1) ⚠⚠ KAPI — NORMALIZE EDILMIS YONTEM ERP ILE TUTUYOR MU? ############"
echo "   V3 (ham ilk kelime): %92,7  — ESIK %95 — GECMEDI."
echo "   V4: bosluk at + sinirli kalip + ZR->R. Simdi kac?"
ORAN=$($PSQL -tA -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
n AS (
  SELECT s.kalem_kodu, s.adet, e.ebat AS erp,
         NULLIF(replace(
           substring(replace(upper(s.kalem_tanimi),' ','')
                     from '^([0-9]{2,3}(/[0-9]{2,3})?(\.[0-9]{2})?Z?R[0-9]{2}(\.[0-9])?C?)'),
           'ZR','R'),'') AS turetilmis
    FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT round(100.0*count(*) FILTER (WHERE turetilmis = erp)/NULLIF(count(*),0),1) FROM n;")
echo "  ✅ TUTMA ORANI: %$ORAN"

$PSQL -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
n AS (
  SELECT s.kalem_kodu, s.adet, s.kalem_tanimi, e.ebat AS erp,
         NULLIF(replace(
           substring(replace(upper(s.kalem_tanimi),' ','')
                     from '^([0-9]{2,3}(/[0-9]{2,3})?(\.[0-9]{2})?Z?R[0-9]{2}(\.[0-9])?C?)'),
           'ZR','R'),'') AS turetilmis
    FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT CASE WHEN turetilmis = erp THEN '✅ TUTTU'
            WHEN turetilmis IS NULL THEN '❓ KALIP YAKALAMADI'
            ELSE '❌ FARKLI' END AS durum,
       count(*) AS sku, round(sum(adet)) AS adet,
       round(100.0*count(*)/sum(count(*)) OVER (),1) AS pct
  FROM n GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "   -- HALA FARKLI olanlar --"
$PSQL -c "
WITH e AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
n AS (
  SELECT s.kalem_tanimi, s.adet, e.ebat AS erp,
         NULLIF(replace(
           substring(replace(upper(s.kalem_tanimi),' ','')
                     from '^([0-9]{2,3}(/[0-9]{2,3})?(\.[0-9]{2})?Z?R[0-9]{2}(\.[0-9])?C?)'),
           'ZR','R'),'') AS turetilmis
    FROM bi_stok_anlik s JOIN e ON e.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT left(kalem_tanimi,36) AS kalem, turetilmis, erp, adet
  FROM n WHERE turetilmis IS DISTINCT FROM erp ORDER BY adet DESC LIMIT 10;"

# ⚠ KAPI
if (( $(echo "$ORAN < 98" | bc -l) )); then
  echo
  echo "❌ KAPI KAPALI: tutma orani %$ORAN, esik %98."
  echo "   Yontem YETERINCE DOGRU DEGIL. YAMA UYGULANMADI."
  echo "   Yeni SKU'larda ebat turetmeyi KULLANMIYORUZ — uydurmaktansa BOS birakiriz."
  exit 1
fi
echo "  ✅ KAPI ACIK (>= %98)"

echo
echo "############ 2) YAMA ############"
if grep -q "ONSIPARIS_V4" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_onsip4
  python3 patch_onsiparis4.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_onsip4 server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_onsip4 server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 4) ⚠ KIS STOGU — normalize sonrasi ebat kapsami ############"
$PSQL -c "
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN ke.ebat IS NOT NULL THEN '1️⃣ ERP ebati'
            WHEN NULLIF(replace(substring(replace(upper(s.kalem_tanimi),' ','')
                 from '^([0-9]{2,3}(/[0-9]{2,3})?(\.[0-9]{2})?Z?R[0-9]{2}(\.[0-9])?C?)'),'ZR','R'),'')
                 IS NOT NULL THEN '3️⃣ turetilmis (normalize)'
            ELSE '❌ ESLESMIYOR' END AS kademe,
       count(*) AS sku, round(sum(s.adet)) AS kis_adet
  FROM bi_stok_anlik s LEFT JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 AND s.sezon ILIKE '%KIS%'
 GROUP BY 1 ORDER BY 3 DESC;"

git add -A && git commit -q -m "fix(sezon): ONSIPARIS_V4 — ebat normalizasyonu. V3'un oz-dogrulamasi %92,7 ile ESIKTEN GECMEDI (esik %95). Sebep sistematikti: 'Z' hiz endeksi (225/45ZR17 vs 225/45R17) ve 'R' oncesi bosluk (225/75 R17.5). Ayni lastik, farkli yazim -> normalize edilmezse ayri ebat sanilir -> mevcut stok bolunur -> eksik siser -> FAZLA SIPARIS. Cozum: bosluk at + sinirli kalip + ZR->R. Deploy %98 kapisina bagli." && echo "  COMMITTED"
