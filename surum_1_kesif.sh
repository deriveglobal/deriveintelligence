#!/usr/bin/env bash
# SURUM_1_KESIF — SADECE OKUR. Otomatik surumleme icin build akisini anla.
#   Amac: dosya degisince ?v= ZORUNLU degissin. Insan hatasi imkansiz olsun.
#   Once: Dockerfile nasil? shell dosyalari nasil referanslaniyor? hepsi ?v='li mi?
set -u
cd /opt/krb-assessment || exit 1

echo "############ 1) DOCKERFILE — build adimlari ############"
if [ -f Dockerfile ]; then
  cat -n Dockerfile | sed 's/^/  /'
else
  echo "  ⚠ Dockerfile yok — baska isim?"
  ls -la | grep -i docker | sed 's/^/  /'
fi

echo
echo "############ 2) ⚠ TUM shell/asset referanslari — ?v='li mi ?v='siz mi? ############"
echo "  --- app.js icinde import edilen /shells/*.js ---"
grep -oE '/shells/[a-zA-Z_.-]+\.js(\?v=[0-9a-zA-Z-]+)?' app.js | sort -u | sed 's/^/  /'
echo
echo "  --- index.html icinde src= ile yuklenen *.js ---"
grep -oE 'src="[^"]+\.js(\?v=[0-9a-zA-Z-]+)?"' index.html | sort -u | sed 's/^/  /'
echo
echo "  --- homepage.html icinde *.js ---"
grep -oE 'src="[^"]+\.js(\?v=[0-9a-zA-Z-]+)?"' homepage.html 2>/dev/null | sort -u | sed 's/^/  /'

echo
echo "############ 3) ⚠ ?v='SIZ yuklenen var mi? (onlar cache tuzagi) ############"
echo "  --- /shells/*.js referanslari ?v= OLMADAN ---"
grep -oE '/shells/[a-zA-Z_.-]+\.js"' app.js | sort -u | sed 's/^/  ⚠ ?v= YOK: /'
grep -oE '/shells/[a-zA-Z_.-]+\.js`' app.js | sort -u | sed 's/^/  ⚠ ?v= YOK: /'

echo
echo "############ 4) shells/ klasorundeki GERCEK .js dosyalari (yedekler haric) ############"
ls shells/*.js 2>/dev/null | grep -v '\.bak' | sed 's/^/  /'

echo
echo "############ 5) ⚠ mevcut ?v= degerleri — elle mi konmus? ############"
grep -rnoE '[a-zA-Z_]+\.js\?v=[0-9a-zA-Z-]+' app.js index.html homepage.html 2>/dev/null | sort -u | sed 's/^/  /'

echo
echo "############ 6) deploy guard #70 — 'truncated shell' kapisi NEREDE? ############"
find /opt/krb-assessment -maxdepth 2 -name '*.sh' 2>/dev/null | xargs grep -l 'truncat\|kesik\|node --check\|guard' 2>/dev/null | head | sed 's/^/  /'
ls -la /opt/krb-assessment/*.sh 2>/dev/null | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ⚠ Plan: build sirasinda her shell dosyasinin ICERIK HASH'i ?v='e yazilsin."
echo "     Dockerfile RUN adimi -> imaj icinde damgalar -> host temiz kalir, unutmak IMKANSIZ."
echo "  ⚠ Once ?v='siz yuklenen dosya var mi onu gorelim — onlar zaten kirik."
