#!/usr/bin/env bash
# TEMA_V2 dagitim — tokenler + tema anahtari. GERIYE DONUK UYUMLU.
#
# ⚠ BU YAMA HICBIR SEYI BOZMAZ:
#   Token blogu mevcut CSS'in ONUNE ekleniyor. Eski kurallar sonra
#   geldigi icin HALA KAZANIYOR. Yani ekran BUGUNKU gibi gorunecek —
#   ama artik --zemin-0, --kirmizi, .kart, .n gibi tokenler MEVCUT,
#   ve yeni yazacagimiz her ekran onlari kullanacak.
#
# ⚠ Pazartesi canli. Gradient temizligi (45 yer) ve tablo->kart (40 tablo)
#   TEK SEFERDE YAPILMIYOR. Oda oda, her biri ayri dogrulanarak.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 0) ANCHOR DOGRULAMA (yamadan once) ############"
echo "── bi.js: vmoStyles() nerede? ──"
grep -n "function vmoStyles" shells/bi.js | head -2
sed -n "$(grep -n 'function vmoStyles' shells/bi.js | head -1 | cut -d: -f1),+2p" shells/bi.js
echo
echo "── saha.js: .saha-app{ nerede? ──"
grep -n "\.saha-app\s*{" shells/saha.js | head -2

echo
echo "############ 1) YEDEK ############"
cp shells/bi.js   shells/bi.js.bak_tema2
cp shells/saha.js shells/saha.js.bak_tema2
BI_ONCE=$(wc -c < shells/bi.js)
SA_ONCE=$(wc -c < shells/saha.js)
echo "  bi.js   $BI_ONCE B"
echo "  saha.js $SA_ONCE B"

echo
echo "############ 2) YAMA ############"
python3 patch_tema2.py || { echo "❌ yamaci patladi — geri aliniyor"
  cp shells/bi.js.bak_tema2 shells/bi.js; cp shells/saha.js.bak_tema2 shells/saha.js; exit 1; }

echo
echo "############ 3) ⚠ KAPI: SOZDIZIMI ############"
for F in shells/bi.js shells/saha.js; do
  node --check "$F" || { echo "  ❌ NODE FAIL: $F — GERI ALINIYOR"
    cp shells/bi.js.bak_tema2 shells/bi.js; cp shells/saha.js.bak_tema2 shells/saha.js; exit 1; }
  echo "  ✅ node --check: $F"
done

echo
echo "############ 4) ⚠ KAPI: BUYUDU MU? ############"
BI_SONRA=$(wc -c < shells/bi.js)
SA_SONRA=$(wc -c < shells/saha.js)
echo "  bi.js   $BI_ONCE -> $BI_SONRA"
echo "  saha.js $SA_ONCE -> $SA_SONRA"
[ "$BI_SONRA" -gt "$BI_ONCE" ] || { echo "  ❌ bi.js buyumedi"; cp shells/bi.js.bak_tema2 shells/bi.js; exit 1; }
[ "$SA_SONRA" -gt "$SA_ONCE" ] || { echo "  ❌ saha.js buyumedi"; cp shells/saha.js.bak_tema2 shells/saha.js; exit 1; }

echo
echo "############ 5) ⚠ KAPI: TOKENLER GERCEKTEN ORADA MI? ############"
for F in shells/bi.js shells/saha.js; do
  for T in -- "--zemin-0" "--kirmizi" "--dokunma" "data-tema=\"acik\"" "tabular-nums"; do
    [ "$T" = "--" ] && continue
    grep -q -- "$T" "$F" || { echo "  ❌ $F içinde YOK: $T"
      cp shells/bi.js.bak_tema2 shells/bi.js; cp shells/saha.js.bak_tema2 shells/saha.js; exit 1; }
  done
  echo "  ✅ $F: tokenler yerinde"
done

echo
echo "############ 6) DAGIT ############"
docker cp shells/bi.js   krb-assessment:/app/shells/bi.js
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 7) ⚠ CANLI DOGRULAMA — token servis ediliyor mu? ############"
curl -s http://localhost:8080/shells/bi.js   | grep -c -- "--zemin-0" | xargs -I{} echo "  bi.js   canlida --zemin-0: {} kez"
curl -s http://localhost:8080/shells/saha.js | grep -c -- "--zemin-0" | xargs -I{} echo "  saha.js canlida --zemin-0: {} kez"

echo
echo "############ 8) ⚠ NE DEGISMEDI — durustce ############"
echo "  Ekran BUGUNKU gibi gorunuyor. Bu KASITLI."
echo "  Token blogu mevcut CSS'in ONUNE eklendi -> eski kurallar hala kazaniyor."
echo "  Kalan borc (oda oda temizlenecek):"
echo "    • gradient/golge/glow : bi $(grep -c 'linear-gradient\|box-shadow\|blur(' shells/bi.js) · saha $(grep -c 'linear-gradient\|box-shadow\|blur(' shells/saha.js)"
echo "    • font-weight 600/700 : bi $(grep -c 'font-weight:\s*[67]00\|font-weight:\s*bold' shells/bi.js) · saha $(grep -c 'font-weight:\s*[67]00\|font-weight:\s*bold' shells/saha.js)"
echo "    • <table> (mobilde kart olacak) : bi $(grep -c '<table' shells/bi.js) · saha $(grep -c '<table' shells/saha.js)"

git add -A && git commit -q -m "feat(tasarim): TEMA_V2 — tek token seti, iki tema, mobil-once. tema.css TEK KAYNAK, yamaci her iki shell'e (bi+saha) basiyor. Tema CIHAZA bagli, module degil: prefers-color-scheme + localStorage ezme, FOUC onleyici senkron onyukleyici. ⚠ Renkler iki temada AYNI HEX DEGIL — koyu temanin #FF6B5A'si beyazda okunmaz, acikta #C43D28. Sari beyazda gorunmez -> kehribar #8A5D06. Anlam ayni, deger farkli. Asistan girdisi 16px sabit (iOS 16px altinda otomatik ZOOM yapar). env(safe-area-inset-bottom) — iPhone alt centigi. Dokunma hedefi >=44px. GERIYE DONUK UYUMLU: tokenler mevcut CSS'in ONUNE eklendi, eski kurallar hala kazaniyor, ekran degismedi. Gradient (45) / font-weight 700 (389) / tablo (40) temizligi AYRI, oda oda — Pazartesi canli, hepsini birden degistirmiyoruz." && echo "  COMMITTED"

echo
echo "✅ Geri alma:"
echo "  cp shells/bi.js.bak_tema2 shells/bi.js && cp shells/saha.js.bak_tema2 shells/saha.js && \\"
echo "  docker cp shells/bi.js krb-assessment:/app/shells/bi.js && \\"
echo "  docker cp shells/saha.js krb-assessment:/app/shells/saha.js && docker restart krb-assessment"
