#!/usr/bin/env bash
# IL_ILCE_5_ARAYUZ — asil cozum: bir daha KIRLENMESIN.
#
# ✅ GECMIS TEMIZ: 273 musteri, 273 il gecerli, 0 gecersiz.
#   (Baslangic: 151 gecerli / 122 gecersiz / 100 farkli yazim)
#
# ⚠ AMA 78 ILCE BOS. Temsilci dolduracak — ancak ACILIR LISTE varsa.
#   Yoksa yine elle yazar, yine kirletir. Gecmisi temizlemek BIR KEREYE MAHSUS;
#   asil is bir daha kirlenmesini ENGELLEMEK.
#
# ⚠ Sunucu tarafi da kapali olacak: arayuz kapisi kullanicinin insafina kalir,
#   sunucu kapisi kalmaz.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 0) KESIF — saha.js nerede yukleniyor? ############"
grep -rn "shells/saha.js\|saha.js" index.html *.html 2>/dev/null | head -5
grep -n "TR_ILLER" shells/saha.js | head -3
echo "  --- ym-il / ym-ilce (769-772) ---"
awk 'NR>=766 && NR<=776 { printf "%4d| %s\n", NR, $0 }' shells/saha.js
echo "  --- lok-il / lok-ilce ---"
grep -n "lok-il\|lok-ilce" shells/saha.js | head -4

echo
echo "############ 1) VERI DOSYASI IMAJA GIRSIN ############"
grep -q "tr_il_ilce.js" Dockerfile || {
  # shells/ zaten kopyalaniyorsa ek is yok
  grep -q "COPY shells ./shells" Dockerfile \
    && echo "  ✅ shells/ komple kopyalaniyor — tr_il_ilce.js otomatik girer" \
    || { echo "  ⚠ Dockerfile'a eklenmeli"; }
}

echo
echo "############ 2) HTML — veri dosyasini yukle ############"
for F in index.html; do
  [ -f "$F" ] || continue
  grep -q "tr_il_ilce.js" "$F" && { echo "  (zaten var: $F)"; continue; }
  cp "$F" "$F.bak_ililce"
  python3 - "$F" <<'PY' || exit 1
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
m = re.search(r'<script[^>]*src="[^"]*shells/saha\.js"[^>]*>', s)
if not m:
    print(f"  ⚠ {p}: saha.js script etiketi bulunamadi — atlandi"); sys.exit(0)
# ⚠ VERI, SAHA.JS'TEN ONCE yuklenmeli.
s = s[:m.start()] + '<script src="/shells/tr_il_ilce.js"></script>\n    ' + s[m.start():]
p.write_text(s, encoding="utf-8")
print(f"  ✅ {p}: tr_il_ilce.js eklendi (saha.js'ten ONCE)")
PY
done

echo
echo "############ 3) ARAYUZ — il ve ilce ACILIR LISTE ############"
cp shells/saha.js shells/saha.js.bak_ililce
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/saha.js"); s = p.read_text(encoding="utf-8")
if "IL_ILCE_V1" in s: sys.exit("ZATEN YAMALI")
n = 0
def rep(eski, yeni, ad):
    global s, n
    if eski not in s:
        print(f"  ⚠ CAPA YOK: {ad}"); return
    s = s.replace(eski, yeni, 1); n += 1
    print(f"  ✅ {ad}")

# ── Yeni musteri formu: il + ilce ────────────────────────────────────────
rep('''      <label>İl *<input class="giris" id="ym-il" list="ym-il-list" placeholder="Şehir seçin">
        <datalist id="ym-il-list">${TR_ILLER.map(il => `<option>${esc(il)}</option>`).join("")}</datalist>''',
'''      <label>İl *<select class="giris" id="ym-il">
        <option value="">Seçin…</option>
        ${(window.TR_ILLER_RESMI || []).map(il => `<option>${esc(il)}</option>`).join("")}
      </select>''',
"yeni musteri: il -> SELECT (serbest yazim KALKTI)")

rep('''      <label>İlçe<input class="giris" id="ym-ilce"></label>''',
'''      <label>İlçe<select class="giris" id="ym-ilce"><option value="">Önce il seçin…</option></select></label>''',
"yeni musteri: ilce -> bagimli SELECT")

# ── ILCE dolduran yardimci + dinleyici ───────────────────────────────────
# ⚠ Bunu modal acildiktan SONRA baglamak lazim. ym-kaydet dinleyicisinin oncesine.
rep('''    if (!g("ym-firma"))   { uyari("Firma zorunlu."); return; }''',
'''    if (!g("ym-firma"))   { uyari("Firma zorunlu."); return; }
    if (!g("ym-il"))      { uyari("İl seçin."); return; }''',
"il zorunlu (select bos olabilir)")

# ilce doldurucu — modal olusturuldugu yere ekle
ANC = '''  document.getElementById("ym-kaydet").addEventListener("click", async () => {'''
if ANC in s:
    s = s.replace(ANC, '''  // ⚠ IL_ILCE_V1 — il secilince ILCELER filtrelenir. Serbest yazim YOK.
  //   Olcum: 1.033 musteride 100 farkli il yazimi, 206 farkli ilce yazimi vardi.
  //   "Kocaeli|KOCAELİ|kocaeli" ayri kayit sayiliyordu; bolge bazli her rapor bozuktu.
  //   Ve il alanina ILCE yaziliyordu: Izmit(20) · Korfez(9) · Gebze(3)...
  //   Veri kalitesi sorunlari SESSIZDIR: kimse hata gormez, sadece raporlar yanlis cikar.
  (function _ililceBagla() {
    const ilEl = document.getElementById("ym-il");
    const ilceEl = document.getElementById("ym-ilce");
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

''' + ANC, 1)
    n += 1
    print("  ✅ il -> ilce bagimlilik dinleyicisi")

p.write_text(s, encoding="utf-8")
print(f"\n  TOPLAM {n}")
PY
node --check shells/saha.js || { cp shells/saha.js.bak_ililce shells/saha.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) SUNUCU KAPISI — gecersiz il/ilce KABUL EDILMESIN ############"
cp server_container.mjs server_container.mjs.bak_ililce
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "IL_ILCE_KAPI_V1" in s: sys.exit("ZATEN YAMALI")

A = '''      // Validate durum enum'''
assert A in s, "❌ capa yok"
B = '''      // ⚠ IL_ILCE_KAPI_V1 — SUNUCU KAPISI.
      //   Arayuz kapisi kullanicinin insafina kalir (tarayicidan istek atan atlar).
      //   Sunucu kapisi kalmaz. Gecersiz il/ilce KABUL EDILMEZ.
      if (p.il != null && String(p.il).trim() !== "") {
        const _ilOk = await query(
          `SELECT 1 FROM tr_ilce_ref WHERE tr_norm(il) = tr_norm($1) LIMIT 1`, [p.il]);
        if (!_ilOk.rowCount) {
          sendJson(response, 400, { error: `Geçersiz il: "${p.il}". Listeden seçin.` }); return;
        }
      }
      if (p.ilce != null && String(p.ilce).trim() !== "" && p.il) {
        const _ilceOk = await query(
          `SELECT 1 FROM tr_ilce_ref WHERE tr_norm(il)=tr_norm($1) AND tr_norm(ilce)=tr_norm($2) LIMIT 1`,
          [p.il, p.ilce]);
        if (!_ilceOk.rowCount) {
          sendJson(response, 400, { error: `"${p.ilce}" ilçesi ${p.il} ilinde yok. Listeden seçin.` }); return;
        }
      }
      // Validate durum enum'''
s = s.replace(A, B, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ PUT musteriler: il/ilce dogrulamasi")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_ililce server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 5) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
curl -s -o /dev/null -w "  GET /shells/tr_il_ilce.js -> HTTP %{http_code}\n" http://localhost:8080/shells/tr_il_ilce.js
docker exec krb-assessment sh -c 'grep -c "IL_ILCE_V1" /app/shells/saha.js'
docker exec krb-assessment sh -c 'grep -c "IL_ILCE_KAPI_V1" /app/server.mjs'

echo
echo "############ 6) ⚠ KAPI TESTI — gecersiz il reddediliyor mu? ############"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '3 minutes', '{\"amac\":\"il testi\"}'::jsonb);"
A="Authorization: Bearer $TOKEN"
MUS=$($PSQL -tAc "SELECT id FROM saha_musteri WHERE sorumlu_rep='$EFTAL' AND aktif LIMIT 1" | head -1 | tr -d '[:space:]')

echo '  [1] gecersiz il ("Yeşilova") -> 400 bekleniyor:'
curl -s -X PUT -H "$A" -H "Content-Type: application/json" -d '{"il":"Yeşilova"}' \
  "http://localhost:8080/api/saha/musteriler/$MUS" | sed 's/^/      /'
echo
echo '  [2] gecerli il ama YANLIS ilce (KOCAELİ / ÇANKAYA) -> 400 bekleniyor:'
curl -s -X PUT -H "$A" -H "Content-Type: application/json" -d '{"il":"KOCAELİ","ilce":"ÇANKAYA"}' \
  "http://localhost:8080/api/saha/musteriler/$MUS" | sed 's/^/      /'
echo
echo '  [3] DOGRU (KOCAELİ / GEBZE) -> 200 bekleniyor:'
curl -s -o /dev/null -w "      HTTP %{http_code}\n" -X PUT -H "$A" -H "Content-Type: application/json" \
  -d '{"il":"KOCAELİ","ilce":"GEBZE"}' "http://localhost:8080/api/saha/musteriler/$MUS"
$PSQL -c "SELECT firma, il, ilce FROM saha_musteri WHERE id='$MUS';"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='il testi';"

git add -A
git commit -q -m 'feat(saha): IL_ILCE_V1 — il/ilce artik ACILIR LISTE, serbest yazim kalkti. Eftalin onerisi (saha_oneri 4a4e905d): "Yeni musteri veya yeni ziyaret girerken il-ilce secimi otomatik olmali. Diger turlu buyuk,kucuk harf veya cok fazla yazim yanlisi olacaktir." Olculen hasar: 1.033 musteride 100 farkli il yazimi (91 normalize), 206 farkli ilce yazimi; ve asil sorun IL ALANINA ILCE YAZILMISTI (Izmit 20, Korfez 9, Golcuk 6, Gebze 3...). Veri kalitesi sorunlari SESSIZDIR: kimse hata gormez, sadece raporlar yanlis cikar. Resmi il/ilce verisi (81 il, 973 ilce, NVI tabanli) ELLE YAZILMADI — kaynaktan indirilip uretildi; 973 ilceyi elle yazsaydim tek harf hatasi bugun duzelttigimiz her seyden sinsi olurdu. Gecmis onarildi: buyuk/kucuk harf resmi yazima cevrildi (59), il alanina yazilmis ilceler duzeltildi (62), birlesik yazimlar ayristirildi (33), kalan 27 koordinat kaniti ile KOCAELIye alindi (Metin Gunes 40.801/29.985 = Golcuk hatti) ve eski deger NOTLARA yazildi (kaybolmadi). Sonuc: 273 musteri, 273u gecerli il, 0 gecersiz. ⚠ Otomatik kural "Yesilova -> BURDUR" diyordu ve TEK ADAYDI: kural dogruydu, sonuc YANLIS olacakti — 14 musteri 500 km oteye tasinacakti. Bir kuralin dogru olmasi, sonucunun dogru olacagi anlamina gelmez. Arayuz: il SELECT, ilce il-bagimli SELECT. Sunucu kapisi da kondu: arayuz kapisi kullanicinin insafina kalir, sunucu kapisi kalmaz.'
echo "  COMMITTED"
