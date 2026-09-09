#!/usr/bin/env bash
# ILCE_6_YAMA — iki gercek duzeltme:
#   A) lok- (Lokasyon Ekle) formu: il/ilce input -> bagimli SELECT
#   B) saha.js ?v= SURUM BUMP — bugunku tum saha degisiklikleri Eftal'e ULASSIN
#      (no-cache yeterli olmali ama ?v= bu deponun yayin sinyali; bump edilmemis)
#
# ⚠ Ankrajlar ilce_5'te dosyadan OKUNDU:
#   1951 lok-il <input> · 1952 lok-ilce <input> · 2023 lokYukle(); (dinleyici buraya)
#   2032 reset forEach (reset sonrasi ilce yenilenmeli)
set -u
cd /opt/krb-assessment || exit 1
SJ=shells/saha.js
cp -a "$SJ" "$SJ.bak_lokilce"
cp -a app.js app.js.bak_vbump

echo "############ A) lok- form: input -> SELECT + dinleyici ############"
python3 - <<'PY'
import io, re, sys
p = "shells/saha.js"
s = io.open(p, encoding="utf-8").read()

if 'id="lok-il"' not in s:
    print("  ❌ lok-il bulunamadi — DURDUM"); sys.exit(1)

# --- A1) il <input> -> <select> (window.TR_ILLER_RESMI) ---
il_eski = '<label>İl<input class="giris" id="lok-il"></label>'
il_yeni = ('<label>İl<select class="giris" id="lok-il">'
           '<option value="">Seçin…</option>'
           '${(window.TR_ILLER_RESMI || []).map(il => `<option>${esc(il)}</option>`).join("")}'
           '</select></label>')
assert il_eski in s, "❌ lok-il <input> ankraji birebir bulunamadi"
s = s.replace(il_eski, il_yeni, 1)
print("  ✅ lok-il -> SELECT")

# --- A2) ilce <input> -> bagimli <select> ---
ilce_eski = '<label>İlçe<input class="giris" id="lok-ilce"></label>'
ilce_yeni = ('<label>İlçe<select class="giris" id="lok-ilce">'
             '<option value="">Önce il seçin…</option></select></label>')
assert ilce_eski in s, "❌ lok-ilce <input> ankraji bulunamadi"
s = s.replace(ilce_eski, ilce_yeni, 1)
print("  ✅ lok-ilce -> bagimli SELECT")

# --- A3) dinleyici: lokYukle(); satirindan HEMEN sonra ---
ank = "  lokYukle();\n"
assert ank in s, "❌ 'lokYukle();' ankraji bulunamadi"
dinleyici = ank + '''  // ⚠ IL_ILCE (lok-): il secilince ilceler filtrelenir. Serbest yazim YOK.
  (function _lokIlIlce(){
    const ilEl = document.getElementById("lok-il");
    const ilceEl = document.getElementById("lok-ilce");
    if (!ilEl || !ilceEl) return;
    const doldur = () => {
      const il = ilEl.value;
      const liste = (window.TR_IL_ILCE || {})[il] || [];
      ilceEl.innerHTML = '<option value="">' + (il ? "İlçe seçin…" : "Önce il seçin…") + '</option>'
        + liste.map(x => '<option>' + esc(x) + '</option>').join("");
    };
    ilEl.addEventListener("change", doldur);
    doldur();
  })();
'''
s = s.replace(ank, dinleyici, 1)
print("  ✅ lok il->ilce dinleyicisi eklendi")

# --- A4) reset sonrasi ilce'yi yenile (aksi halde eski il'in ilceleri gorunur kalir) ---
reset_eski = '["lok-ad", "lok-il", "lok-ilce"].forEach(id => document.getElementById(id).value = "");'
assert reset_eski in s, "❌ reset forEach ankraji bulunamadi"
reset_yeni = (reset_eski +
              '\n      document.getElementById("lok-il").dispatchEvent(new Event("change"));')
s = s.replace(reset_eski, reset_yeni, 1)
print("  ✅ reset sonrasi ilce yenileniyor")

io.open(p, "w", encoding="utf-8").write(s)
PY

echo
echo "############ A5) SOZDIZIMI (saha.js) ############"
if node --check "$SJ" >/dev/null 2>&1; then echo "  ✅ node --check"; else
  echo "  ❌ BOZUK — GERI ALIYORUM"; node --check "$SJ" 2>&1 | head -5
  cp -a "$SJ.bak_lokilce" "$SJ"; exit 1; fi

echo
echo "############ B) ?v= SURUM BUMP — saha.js (app.js icinde) ############"
python3 - <<'PY'
import io, sys
p = "app.js"
s = io.open(p, encoding="utf-8").read()
eski = '/shells/saha.js?v=20260707-18'
yeni = '/shells/saha.js?v=20260714-2'
assert eski in s, "❌ eski saha.js ?v= bulunamadi"
n = s.count(eski)
s = s.replace(eski, yeni)
io.open(p, "w", encoding="utf-8").write(s)
print(f"  ✅ saha.js ?v= : 20260707-18 -> 20260714-2  ({n} yer)")
PY
if node --check app.js >/dev/null 2>&1; then echo "  ✅ node --check app.js"; else
  echo "  ❌ app.js BOZUK — GERI"; cp -a app.js.bak_vbump app.js; exit 1; fi

echo
echo "############ B2) app.js ?v= — index.html icinde bump (app.js taze gelsin) ############"
python3 - <<'PY'
import io, re
p = "index.html"
s = io.open(p, encoding="utf-8").read()
m = re.search(r'app\.js\?v=([0-9-]+)', s)
if not m:
    print("  ⚠ index.html'de app.js ?v= bulunamadi — atlandi"); raise SystemExit
eski = m.group(0)
yeni = 'app.js?v=20260714-2'
s = s.replace(eski, yeni)
io.open(p, "w", encoding="utf-8").write(s)
print(f"  ✅ index.html: {eski} -> {yeni}")
PY

echo
echo "############ C) DAGIT ############"
docker build -t krb-assessment:secure . >/tmp/b.log 2>&1 || { echo "❌ BUILD"; tail -20 /tmp/b.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET /                     -> $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)"
echo "  GET /app.js               -> $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/app.js)"
echo "  GET /shells/saha.js       -> $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/shells/saha.js)"

echo
echo "############ D) ⚠ KANIT — servis edilen dosyalar ############"
echo "  --- index.html app.js surumu ---"
curl -s http://localhost:8080/ | grep -o 'app.js?v=[0-9-]*' | sed 's/^/    /'
echo "  --- app.js saha.js import surumu ---"
curl -s http://localhost:8080/app.js | grep -o 'saha.js?v=[0-9-]*' | sed 's/^/    /'
echo "  --- lok-il / lok-ilce artik SELECT mi? ---"
curl -s http://localhost:8080/shells/saha.js | grep -o '<select class="giris" id="lok-il[ce]*"' | sed 's/^/    /'
LOKIN=$(curl -s http://localhost:8080/shells/saha.js | grep -c '<input class="giris" id="lok-il')
echo "    kalan <input id=lok-il...>: $LOKIN   ⚠ 0 olmali"

echo
echo "############ SONUC ############"
echo "  ⚠ Eftal uygulamayi KAPAT-AC (ya da yenile) — yeni ?v= sayesinde kesinlikle yeni dosyayi alir."
echo "  ⚠ Yeni musteri: il+ilce zaten acilir. Lokasyon Ekle: artik il+ilce acilir."
echo "  ⚠ Geri donus: shells/saha.js.bak_lokilce · app.js.bak_vbump"
