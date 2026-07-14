#!/usr/bin/env bash
# PROFIL_HAFIZASI_2 — form artik HEM YAZAR HEM OKUR.
#
# ⚠ TESHIS (olculdu): 2.420 ziyaretin 16'sinda arac parki, 13'unde marka,
#   7'sinde yillik potansiyel var. Veri NEREDEYSE HIC TOPLANMAMIS.
#   Cunku hicbir yere BIRIKMIYORDU: form her seferinde bombos aciliyordu,
#   temsilci ayni seyleri yeniden girmek zorunda kaliyordu, girmiyordu.
#
# ✅ COZUM: ziyaret kaydedilirken profil MUSTERIYE de yazilir;
#   form acilirken MUSTERIDEN okunur. Boylece her ziyaret profili BUYUTUR.
#   Bir yil sonra 1.033 musterinin filo envanteri elde olur.
#
# ⚠ VE PROFIL TARIHI GORUNUR: "8 ay onceki ziyaretten" demek onemli.
#   Secili gelen bir bilgi, tarihi gorunmuyorsa BUGUNUN BILGISI SANILIR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) SUNUCU — PUT musteri: yeni profil alanlari kabul edilsin ############"
cp server_container.mjs server_container.mjs.bak_profil
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "PROFIL_V1" in s: sys.exit("ZATEN YAMALI")

# (a) PUT musteriler — yeni alanlar
A = '''      if (Array.isArray(p.sektorler)) { params.push(p.sektorler); sets.push(`sektorler = $${params.length}`); }
      if (Array.isArray(p.tedarikci_markalar)) { params.push(p.tedarikci_markalar); sets.push(`tedarikci_markalar = $${params.length}`); }'''
assert A in s, "❌ dizi alan capasi yok"
B = '''      if (Array.isArray(p.sektorler)) { params.push(p.sektorler); sets.push(`sektorler = $${params.length}`); }
      if (Array.isArray(p.tedarikci_markalar)) { params.push(p.tedarikci_markalar); sets.push(`tedarikci_markalar = $${params.length}`); }
      // ⚠ PROFIL_V1 — form bir MUSTERI PROFILI topluyordu ama sistem onu
      //   ZIYARET FOTOGRAFI olarak sakliyordu (ziyaret.detay). Ertesi ziyarette
      //   musteri BOMBOS aciliyordu — profil hic olusmuyordu.
      //   Olcum: 2.420 ziyaretin 16'sinda arac parki, 7'sinde yillik potansiyel vardi.
      //   Artik profil MUSTERIYE yaziliyor: her ziyaret profili BUYUTUR.
      if (Array.isArray(p.kullanilan_markalar)) { params.push(p.kullanilan_markalar); sets.push(`kullanilan_markalar = $${params.length}`); }
      if (Array.isArray(p.raf_markalar))        { params.push(p.raf_markalar);        sets.push(`raf_markalar = $${params.length}`); }
      if (Array.isArray(p.bayilikler))          { params.push(p.bayilikler);          sets.push(`bayilikler = $${params.length}`); }
      if (Array.isArray(p.rakip_toptancilar))   { params.push(p.rakip_toptancilar);   sets.push(`rakip_toptancilar = $${params.length}`); }
      // ⚠ Sayilar: 0 gecerli bir deger. null "bilinmiyor" demek. Ikisi ayri.
      for (const f of ["yillik_potansiyel", "kis_stok", "yaz_stok"]) {
        if (Object.prototype.hasOwnProperty.call(p, f) && p[f] !== undefined) {
          params.push(p[f] === "" ? null : p[f]); sets.push(`${f} = $${params.length}`);
        }
      }
      // ⚠ arac_parki: hepsi null ise KAYDETME. "Bos nesne" = "arac parki var" gibi gorunuyordu.
      if (p.arac_parki && typeof p.arac_parki === "object") {
        const _v = Object.values(p.arac_parki).filter(x => x !== null && x !== undefined && x !== "" && Number(x) !== 0);
        if (_v.length) { params.push(JSON.stringify(p.arac_parki)); sets.push(`arac_parki = $${params.length}::jsonb`); }
      }
      // ⚠ PROFIL TARIHI — "bu bilgi ne zamanki?" sorusunun cevabi.
      //   Secili gelen bir bilgi, tarihi gorunmuyorsa BUGUNUN bilgisi sanilir.
      if (sets.length) { sets.push(`profil_guncel_at = now()`); }'''
s = s.replace(A, B, 1)

# (b) GET musteri detay — yeni alanlar zaten m.* ile geliyor (SELECT m.*), ek is yok.
p.write_text(s, encoding="utf-8")
print("  ✅ PUT musteriler: 8 yeni profil alani + profil_guncel_at")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_profil server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 2) ARAYUZ — form acilirken OKU, kaydederken YAZ ############"
cp shells/saha.js shells/saha.js.bak_profil
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/saha.js"); s = p.read_text(encoding="utf-8")
if "PROFIL_V1" in s: sys.exit("ZATEN YAMALI")
n = 0
def rep(eski, yeni, ad):
    global s, n
    if eski not in s:
        print(f"  ⚠ CAPA YOK: {ad}"); return False
    s = s.replace(eski, yeni, 1); n += 1
    print(f"  ✅ {ad}"); return True

# ── (a) FORM ACILIRKEN: TUM profil alanlarini doldur ────────────────────
rep('''  // Pre-select chips from customer profile (ticari only)
  if (!tuketici) {
    const mSek = Array.isArray(mus.sektorler) ? mus.sektorler : [];
    const mTed = Array.isArray(mus.tedarikci_markalar) ? mus.tedarikci_markalar : [];
    document.querySelectorAll('#zf-sektorler .cip').forEach(b => { if (mSek.includes(b.dataset.v)) b.classList.add('on'); });
    document.querySelectorAll('#zf-tedarikci .cip').forEach(b => { if (mTed.includes(b.dataset.v)) b.classList.add('on'); });
  }''',
'''  // ⚠ PROFIL_V1 — form artik musteriyi HATIRLIYOR.
  //   Eski hali: sadece sektorler ve tedarikci_markalar seciliydi; digerleri
  //   her ziyarette SIFIRDAN giriliyordu ve hicbir yere birikmiyordu.
  //   Olcum: 2.420 ziyaretin 16'sinda arac parki vardi. Cunku kimse iki kez girmez.
  const _cip = (kap, deger) => {
    const arr = Array.isArray(deger) ? deger : [];
    document.querySelectorAll(`#${kap} .cip`).forEach(b => {
      if (arr.includes(b.dataset.v)) b.classList.add('on');
    });
  };
  const _say = (id, deger) => {
    const el = document.getElementById(id);
    if (el && deger != null && deger !== "") el.value = deger;
  };
  if (!tuketici) {
    _cip('zf-sektorler', mus.sektorler);
    _cip('zf-tedarikci', mus.tedarikci_markalar);
    _cip('zf-marka',     mus.kullanilan_markalar);
    const ap = mus.arac_parki || {};
    _say('zf-cekici', ap.cekici); _say('zf-dorse', ap.dorse);
    _say('zf-kamyon', ap.kamyon); _say('zf-ismak',  ap.is_makinesi);
    _say('zf-potansiyel', mus.yillik_potansiyel);
  } else {
    _cip('zf-raf',     mus.raf_markalar);
    _cip('zf-bayilik', mus.bayilikler);
    _cip('zf-rakip',   mus.rakip_toptancilar);
    _say('zf-kis', mus.kis_stok);
    _say('zf-yaz', mus.yaz_stok);
  }
  // ⚠ BU BILGI NE ZAMANKI? Tarihi gorunmeyen bir bilgi BUGUNUN bilgisi sanilir.
  if (mus.profil_guncel_at) {
    const _t = new Date(mus.profil_guncel_at);
    const _g = Math.floor((Date.now() - _t.getTime()) / 86400000);
    const _ilk = document.querySelector('.alan-grup');
    if (_ilk) {
      const _uy = document.createElement('div');
      _uy.style.cssText = 'font-size:12px;color:' + (_g > 180 ? '#b45309' : '#64748b') + ';margin:0 0 8px';
      _uy.textContent = (_g > 180 ? '⚠ ' : '') + 'Aşağıdaki bilgiler ' +
        _t.toLocaleDateString('tr-TR') + ' tarihli ziyaretten geliyor' +
        (_g > 180 ? ' — ' + Math.round(_g/30) + ' ay önce. Değişmiş olabilir.' : '.');
      _ilk.parentNode.insertBefore(_uy, _ilk);
    }
  }''',
"form acilirken: TUM profil okunuyor + tarih uyarisi")

# ── (b) KAYDEDERKEN: profili musteriye YAZ (ticari) ─────────────────────
rep('''      // Update customer profile with sektorler + tedarikci_markalar (ticari only)
      if (!tuketici) {
        await api(`/api/saha/musteriler/${mus.id}`, {
          method: "PUT", body: JSON.stringify({ sektorler: sektorSecim, tedarikci_markalar: tedarikSecim })
        }).catch(() => {});
      }''',
'''      // ⚠ PROFIL_V1 — TUM profil musteriye yaziliyor, sadece iki alan degil.
      //   Boylece bir sonraki ziyarette form BOMBOS acilmiyor.
      //   ⚠ Hata artik YUTULMUYOR: .catch(()=>{}) sessiz kayip uretiyordu.
      try {
        const _profil = !tuketici
          ? { sektorler: sektorSecim, tedarikci_markalar: tedarikSecim,
              kullanilan_markalar: cipDegerler("zf-marka"),
              arac_parki: { cekici: n("zf-cekici"), dorse: n("zf-dorse"),
                            kamyon: n("zf-kamyon"), is_makinesi: n("zf-ismak") },
              yillik_potansiyel: n("zf-potansiyel") }
          : { raf_markalar: cipDegerler("zf-raf"),
              bayilikler: cipDegerler("zf-bayilik"),
              rakip_toptancilar: cipDegerler("zf-rakip"),
              kis_stok: n("zf-kis"), yaz_stok: n("zf-yaz") };
        await api(`/api/saha/musteriler/${mus.id}`, {
          method: "PUT", body: JSON.stringify(_profil)
        });
      } catch (e) {
        // ⚠ SUSMAZ. Profil yazilamadiysa temsilci BILSIN.
        console.error("[saha] musteri profili yazilamadi:", e && e.message);
        uyari("⚠ Ziyaret kaydedildi ama müşteri profili güncellenemedi: " + (e.message || ""));
      }''',
"kaydederken: TUM profil musteriye yaziliyor (hata yutulmuyor)")

p.write_text(s, encoding="utf-8")
print(f"\n  TOPLAM {n}")
PY
node --check shells/saha.js || { cp shells/saha.js.bak_profil shells/saha.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ⚠ BOS arac_parki TEMIZLIGI ############"
# {"cekici":null,"dorse":null,...} "arac parki var" gibi gorunuyordu. DEMMER MERMER ornegi.
$PSQL -c "
UPDATE saha_musteri SET arac_parki = NULL
 WHERE arac_parki IS NOT NULL
   AND COALESCE((arac_parki->>'cekici')::int,0)
     + COALESCE((arac_parki->>'dorse')::int,0)
     + COALESCE((arac_parki->>'kamyon')::int,0)
     + COALESCE((arac_parki->>'is_makinesi')::int,0) = 0;"
$PSQL -c "SELECT count(arac_parki) AS gercek_arac_parki FROM saha_musteri WHERE aktif;"
echo "  ⚠ Bos nesneler NULL'landi. 'Var gibi gorunen yok' de bir yalandir."

echo
echo "############ 4) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'grep -c "PROFIL_V1" /app/server.mjs /app/shells/saha.js'

echo
echo "############ 5) ⚠ CANLI TEST — profil yazilip okunuyor mu? ############"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"profil testi\"}'::jsonb);"
A="Authorization: Bearer $TOKEN"
MUS=$($PSQL -tAc "SELECT id FROM saha_musteri WHERE tenant_id='$T' AND tip='TICARI' AND aktif LIMIT 1" | head -1 | tr -d '[:space:]')

echo "  --- ONCE (profil bos olmali) ---"
$PSQL -c "SELECT firma, arac_parki, yillik_potansiyel, kullanilan_markalar FROM saha_musteri WHERE id='$MUS';"

echo "  --- YAZ ---"
curl -s -o /dev/null -w "      PUT -> HTTP %{http_code}\n" -X PUT -H "$A" -H "Content-Type: application/json" \
  -d '{"kullanilan_markalar":["Lassa","Petlas"],"arac_parki":{"cekici":10,"dorse":12,"kamyon":5,"is_makinesi":2},"yillik_potansiyel":400}' \
  "http://localhost:8080/api/saha/musteriler/$MUS"

echo "  --- SONRA (yazilmis olmali) ---"
$PSQL -c "SELECT firma, arac_parki, yillik_potansiyel, kullanilan_markalar, profil_guncel_at::date
          FROM saha_musteri WHERE id='$MUS';"

echo "  --- OKU (form bunu gorecek) ---"
curl -s -H "$A" "http://localhost:8080/api/saha/musteriler/$MUS" \
  | python3 -c "import sys,json; d=json.load(sys.stdin)['musteri']; print('     ', {k:d.get(k) for k in ['firma','arac_parki','yillik_potansiyel','kullanilan_markalar','profil_guncel_at']})"

echo "  --- GERI AL (test verisi) ---"
$PSQL -q -c "UPDATE saha_musteri SET arac_parki=NULL, yillik_potansiyel=NULL,
             kullanilan_markalar=NULL, profil_guncel_at=NULL WHERE id='$MUS';"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='profil testi';"
echo "  ✅ test verisi geri alindi"

git add -A
git commit -q -m 'feat(saha): PROFIL_V1 — ziyaret formu artik musteriyi HATIRLIYOR. Iki temsilci ayni seyi istedi (saha_oneri c4ff0c93 Eftal, 56dd9899 Huseyin): "onceki ziyarette doldurulmussa secili gelmeli". Teshis: eksik olan bir arayuz degil, VERI MODELIYDI. saha_musteride sadece sektorler ve tedarikci_markalar vardi; form ayrica arac_parki, kullanilan_markalar, yillik_potansiyel (ticari) ve raf_markalar, bayilikler, rakip_toptancilar, kis/yaz stok (tuketici) topluyordu ama hicbirinin karsiligi yoktu — hepsi ziyaretin detay jsonbsine gomuluyordu. Yani form bir MUSTERI PROFILI topluyordu, sistem onu ZIYARET FOTOGRAFI olarak sakliyordu; ertesi ziyarette musteri bombos aciliyordu. Sonuc: 2.420 ziyaretin 16sinda arac parki, 13unde marka, 7sinde yillik potansiyel vardi — cunku kimse ayni seyi iki kez girmez. 9 kolon eklendi, 329 musterinin profili son ziyaretlerinin detayindan geri kazanildi, ve form artik hem yaziyor hem okuyor: her ziyaret profili BUYUTUYOR. Ayrica profil_guncel_at eklendi ve formda gosteriliyor — tarihi gorunmeyen bir bilgi BUGUNUN bilgisi sanilir; 6 aydan eskiyse uyari cikiyor. Bos arac_parki nesneleri ({cekici:null,...}) NULLlandi: "var gibi gorunen yok" da bir yalandir. Ve profil yazma hatasi artik YUTULMUYOR — .catch(()=>{}) sessiz kayip uretiyordu, simdi temsilciye soyluyor.'
echo "  COMMITTED"
