#!/usr/bin/env bash
set -euo pipefail
cd /opt/krb-assessment
cp shells/saha.js shells/saha.js.bak_nabizfix
trap 'echo ">> HATA — geri aliniyor"; cp shells/saha.js.bak_nabizfix shells/saha.js' ERR
python3 - <<'PY'
path='shells/saha.js'
s=open(path,encoding='utf-8').read()
if 'NABIZ_HIKAYE_V2' in s:
    print("SKIP (zaten V2)")
else:
    old1='        baslangicStripYukle();\n    nabizHikayeYukle(); /* NABIZ_HIKAYE_V1 */'
    if old1 not in s: raise SystemExit("ANCHOR YOK: yanlis-yer cagrisi")
    s=s.replace(old1,'        baslangicStripYukle();',1)
    old2='    baslangicStripYukle();\n\n    // check-in (rep only)'
    if old2 not in s: raise SystemExit("ANCHOR YOK: vBugun baslangicStripYukle")
    s=s.replace(old2,'    baslangicStripYukle();\n    nabizHikayeYukle(); /* NABIZ_HIKAYE_V2 */\n\n    // check-in (rep only)',1)
    open(path,'w',encoding='utf-8').write(s)
    print("PATCHLENDI")
PY
echo ">> node --check"; node --check shells/saha.js
echo ">> build + recreate"
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 4
echo -n ">> V2 marker: "; docker exec krb-assessment grep -c NABIZ_HIKAYE_V2 /app/shells/saha.js || true
docker exec krb-assessment grep -n nabizHikayeYukle /app/shells/saha.js
trap - ERR
echo ">> BITTI"
