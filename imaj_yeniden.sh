#!/usr/bin/env bash
# IMAJ_V2 — bugunku isi KALICI kil. docker cp donemi bitiyor.
#
# ⚠ MEVCUT DURUM (tehlikeli):
#   imaj 6 Temmuz'da derlenmis · konteynerdeki is 14 Temmuz (docker cp ile)
#   `docker compose up --force-recreate` -> sistem 8 GUN GERIYE doner.
#   On saatlik is, tek bir komuta asili duruyor.
#
# ⚠ AYRICA: Dockerfile repodaki server.mjs'i kopyaliyordu — o dosya 9 Temmuz
#   tarihli ve BAYAT. Gercek dosya server_container.mjs. Isim karmasasi.
#
# ✅ BU SCRIPT:
#   1. Yeni imaji AYRI BIR ETIKETLE derler (calisan sistem BOZULMAZ)
#   2. Yeni imajdan GECICI bir konteyner ayaga kaldirip DOGRULAR
#   3. Ancak dogrulama gecerse canliya alir
#   4. Eski imaj :onceki olarak saklanir — geri donus TEK KOMUT
#
# ⚠ HIC BIR ADIMDA "simdilik boyle olsun" YOK.
set -uo pipefail
cd /opt/krb-assessment

ETIKET="krb-assessment:v$(date +%Y%m%d-%H%M)"
echo "############ 0) ON KONTROL ############"
for f in Dockerfile server_container.mjs erp_ingest.py package.json; do
  [ -f "$f" ] || { echo "❌ EKSIK: $f"; exit 1; }
done
echo "  ✅ gerekli dosyalar yerinde"
echo "  server_container.mjs : $(wc -c < server_container.mjs) B"
echo "  erp_ingest.py        : $(wc -c < erp_ingest.py) B"

echo
echo "############ 1) YENI IMAJ — ayri etiket, canliya DOKUNMADAN ############"
docker build -t "$ETIKET" . 2>&1 | tail -6
docker image inspect "$ETIKET" >/dev/null 2>&1 || { echo "❌ DERLEME BASARISIZ — canli sistem DOKUNULMADI"; exit 1; }
echo "  ✅ $ETIKET derlendi"

echo
echo "############ 2) ⚠ KAPI: yeni imajda PYTHON + MOTOR var mi? ############"
docker run --rm "$ETIKET" sh -c '
  python3 -c "import openpyxl, psycopg2; print(\"  ✅ python3 + openpyxl + psycopg2\")" || exit 1
  python3 -c "import ast; ast.parse(open(\"/app/erp_ingest.py\").read()); print(\"  ✅ erp_ingest.py sozdizimi\")" || exit 1
  node --check /app/server.mjs && echo "  ✅ server.mjs sozdizimi" || exit 1
  test -f /app/shells/bi.js && echo "  ✅ shells/bi.js" || exit 1
' || { echo "❌ KAPI DUSTU — canli sistem DOKUNULMADI"; exit 1; }

echo
echo "############ 3) ⚠ KAPI: server.mjs BUGUNKU mu? ############"
IMAJ_MD5=$(docker run --rm "$ETIKET" md5sum /app/server.mjs | cut -c1-32)
REPO_MD5=$(md5sum server_container.mjs | cut -c1-32)
echo "  imajdaki : $IMAJ_MD5"
echo "  repodaki : $REPO_MD5"
[ "$IMAJ_MD5" = "$REPO_MD5" ] || { echo "❌ IMAJDAKI server.mjs BAYAT — canliya ALINMIYOR"; exit 1; }
echo "  ✅ imajdaki server.mjs = bugunku is"

echo
echo "############ 4) ⚠ KAPI: GECICI KONTEYNER — gercekten ayaga kalkiyor mu? ############"
docker rm -f krb-test >/dev/null 2>&1 || true
docker run -d --name krb-test \
  --network krb-assessment_default \
  -e DATABASE_URL="postgres://assessment_app:9951f8de0fd1e54e3553459965eeb0b3fba5fa5aa5baca9a@postgres:5432/assessment_platform" \
  -e NODE_ENV=production -e PORT=3000 \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  -p 127.0.0.1:8099:3000 "$ETIKET" >/dev/null
sleep 10
KOD=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8099/ || echo 000)
echo "  GET / -> HTTP $KOD"
docker logs krb-test 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"
docker rm -f krb-test >/dev/null 2>&1
[ "$KOD" = "200" ] || { echo "❌ YENI IMAJ AYAGA KALKMIYOR — canli sistem DOKUNULMADI"; exit 1; }
echo "  ✅ yeni imaj calisiyor"

echo
echo "############ 5) CANLIYA AL ############"
docker tag krb-assessment:secure krb-assessment:onceki 2>/dev/null || true
echo "  ✅ eski imaj :onceki olarak saklandi (geri donus icin)"
docker tag "$ETIKET" krb-assessment:secure
docker compose up -d --force-recreate krb-assessment 2>&1 | tail -2
sleep 10
echo
echo "############ 6) ⚠ CANLI DOGRULAMA ############"
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'python3 -c "import openpyxl, psycopg2; print(\"  ✅ python KONTEYNERDE (kalici)\")"'
docker exec krb-assessment sh -c 'test -f /app/erp_ingest.py && echo "  ✅ motor imajda (kalici)"'
CANLI=$(docker exec krb-assessment md5sum /app/server.mjs | cut -c1-32)
[ "$CANLI" = "$REPO_MD5" ] && echo "  ✅ canli server.mjs = bugunku is" || echo "  ❌ SAPMA"
for E in /api/bi/yukle/durum /api/bi/ana /api/bi/koken; do
  printf "  %-24s -> HTTP %s\n" "$E" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080$E)"
done
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"

echo
echo "############ 7) ⚠ BUNDAN SONRA ############"
echo "  DAGITIM ARTIK: docker compose build && docker compose up -d"
echo "  DOCKER CP KULLANILMAYACAK — konteyner yeniden yaratilinca kaybolur."
echo "  Geri donus : docker tag krb-assessment:onceki krb-assessment:secure && docker compose up -d --force-recreate krb-assessment"

git add -A
git commit -q -m 'infra: IMAJ_V2 — bugunku is KALICI. Iki ciddi borc kapatildi. (1) Dockerfile repodaki server.mjs i kopyaliyordu; o dosya 9 Temmuz tarihli ve BAYATTI (1,33MB), gercek dosya server_container.mjs (14 Temmuz, 1,57MB). Imaj 6 Temmuzda derlenmisti. Yani `docker compose up --force-recreate` deseydik sistem 8 GUN GERIYE doner, bir gunluk is kaybolurdu; on saatlik is tek bir komuta asili duruyordu. Artik server_container.mjs kopyalaniyor. (2) Dagitim `docker cp` ile yapiliyordu — docker cp konteynerin yazilabilir katmanina yazar, docker restart korur ama force-recreate/imaj yeniden derleme HEPSINI SILER. Artik her sey imajin icinde: server.mjs, shells, VE erp_ingest.py motoru. (3) PYTHON: konteyner USER=node (root degil), calisma aninda apk add CALISMIYORDU; bagimliliklar artik DERLEME ANINDA root asamasinda kuruluyor (py3-psycopg2 apk paketinden, openpyxl pip ile). Dagitim kurali degisti: docker cp YOK, docker compose build && up -d VAR. Eski imaj :onceki olarak saklaniyor, geri donus tek komut. Script canliya dokunmadan once 4 kapidan geciyor: derleme, python+motor varligi, server.mjs guncelligi, ve GECICI KONTEYNERDE gercekten ayaga kalkma.'
echo "  COMMITTED"
