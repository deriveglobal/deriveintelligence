#!/usr/bin/env python3
"""TEMA_V2 — token setini HER IKI shell'e enjekte et.

⚠ MIMARI: bi.js ve saha.js kendi CSS'ini uretiyor (host HTML yok).
   Token blogu her ikisinin stil blokina basiliyor. :root oradan da
   tum belgeye gecer.

⚠ TEK KAYNAK: tema.css. Yamaci onu OKUR. Iki yerde kopya CSS tutmuyoruz —
   ileride tema degisince tek dosya duzenlenir, yamaci tekrar kosar.

⚠ TEMA ONYUKLEYICI: sayfa boyanmadan ONCE <html data-tema> kurulmali.
   Yoksa acik->koyu YANIP SONER (FOUC). Bu yuzden <script> stil blogundan
   once, senkron calisir.

⚠ HICBIR SEY SILINMIYOR. Mevcut CSS oldugu gibi duruyor, token blogu
   ONUNE ekleniyor. Eski kurallar hala kazanir (sonra geldikleri icin).
   Gradient/golge temizligi ve tablo->kart donusumu AYRI, oda oda yapilacak.
   Pazartesi canliya cikacak bir sistemde her seyi birden degistirmek risk.
"""
import re, sys, pathlib

TEMA = pathlib.Path("tema.css")
if not TEMA.exists():
    sys.exit("❌ tema.css yok — once scp ile yukle")
css = TEMA.read_text(encoding="utf-8")

# ⚠ JS template literal icine giriyor: ` ve ${ KACIRILMALI.
#   Kacirilmazsa backtick string'i erken kapatir -> SYNTAX ERROR.
css_js = css.replace("\\", "\\\\").replace("`", "\\`").replace("${", "\\${")

BOOT = """
<script>
(function(){
  try{
    var t = localStorage.getItem('derive_tema');
    if(!t || t==='oto'){
      t = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'acik' : 'koyu';
    }
    document.documentElement.setAttribute('data-tema', t);
  }catch(e){ document.documentElement.setAttribute('data-tema','koyu'); }
})();
window.temaDegistir = function(secim){
  try{ localStorage.setItem('derive_tema', secim); }catch(e){}
  var t = secim;
  if(secim==='oto'){
    t = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'acik' : 'koyu';
  }
  document.documentElement.setAttribute('data-tema', t);
};
</script>
"""


def yamala(dosya, tanim):
    p = pathlib.Path(dosya)
    src = p.read_text(encoding="utf-8")
    if "DERIVE_TEMA_V2" in src:
        print(f"  {dosya}: ZATEN YAMALI, atlandi")
        return src, False

    marker = "/* DERIVE_TEMA_V2 */\n"
    blok = marker + css_js

    for pat, ad in tanim:
        m = re.search(pat, src)
        if m:
            i = m.end()
            src = src[:i] + "\n" + blok + "\n" + src[i:]
            print(f"  {dosya}: token blogu eklendi → {ad} (offset {i})")
            break
    else:
        sys.exit(f"❌ {dosya}: HICBIR ANCHOR TUTMADI. Yama iptal — koru dokunma yok.")

    return src, True


# bi.js — vmoStyles() icindeki return `...` bloğunun BASINA
bi_src, bi_ok = yamala("shells/bi.js", [
    (r"function\s+vmoStyles\s*\([^)]*\)\s*\{\s*return\s*`", "vmoStyles() return backtick"),
    (r"function\s+vmoStyles\s*\([^)]*\)\s*\{\s*return\s*'", "vmoStyles() return quote"),
])

# saha.js — .saha-app{ kuralindan ONCE (o satirin basina)
saha_p = pathlib.Path("shells/saha.js")
saha_src = saha_p.read_text(encoding="utf-8")
saha_ok = False
if "DERIVE_TEMA_V2" in saha_src:
    print("  shells/saha.js: ZATEN YAMALI, atlandi")
else:
    m = re.search(r"\n\s*\.saha-app\s*\{", saha_src)
    if not m:
        sys.exit("❌ saha.js: '.saha-app{' bulunamadi. Yama iptal.")
    i = m.start()
    saha_src = saha_src[:i] + "\n/* DERIVE_TEMA_V2 */\n" + css_js + saha_src[i:]
    print(f"  shells/saha.js: token blogu eklendi → .saha-app oncesi (offset {i})")
    saha_ok = True

if bi_ok:
    pathlib.Path("shells/bi.js").write_text(bi_src, encoding="utf-8")
if saha_ok:
    saha_p.write_text(saha_src, encoding="utf-8")

print("\n  ⚠ Tema onyukleyici (FOUC onleyici) AYRI adimda — head'e gidecek.")
print("  ⚠ Gradient/golge temizligi ve tablo->kart AYRI, oda oda.")
print("     Simdi sadece TOKENLER var. Eski CSS hala kazaniyor (sonra geliyor).")
print("     Bu KASITLI: Pazartesi canli. Her seyi birden degistirmiyoruz.")
