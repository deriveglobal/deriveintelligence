import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "YENI_ZIYARET_DESKTOP_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert s.count(old) == 1, "anchor %s count=%d" % (tag, s.count(old))
    s = s.replace(old, new, 1); print("[ok]", tag)

# 1) "Yeni Ziyaret" butonu — Ziyaretler view baslik satirina
rep(
'          <input class="dk-tsearch" id="ziy-q" placeholder="\U0001F50D firma, şehir, not…" value="${esc(S.q || "")}">',
'          <button class="dk-btn dk-btn-sm" id="ziy-yeni" style="background:#0ea5e9;color:#fff;border-color:#0ea5e9">＋ Yeni Ziyaret</button>\n          <input class="dk-tsearch" id="ziy-q" placeholder="\U0001F50D firma, şehir, not…" value="${esc(S.q || "")}">',
"buton")

# 2) butonu musteriSec -> ziyaretYeniDesktop akisina bagla
rep(
'  qi.addEventListener("input", () => { S.q = qi.value.trim(); clearTimeout(qt); qt = setTimeout(refresh, 200); });',
'  qi.addEventListener("input", () => { S.q = qi.value.trim(); clearTimeout(qt); qt = setTimeout(refresh, 200); });\n  const _yzb = m.querySelector("#ziy-yeni"); if (_yzb) _yzb.addEventListener("click", () => musteriSec(mus => ziyaretYeniDesktop(mus)));  /* YENI_ZIYARET_DESKTOP_V1 */',
"wire")

# 3) ziyaretYeniDesktop() — musteri secildikten sonra ziyaret formu -> POST /api/saha/ziyaretler
FUNC = '''async function ziyaretYeniDesktop(mus) {  /* YENI_ZIYARET_DESKTOP_V1 */
  if (!mus || !mus.id) { alert("M\\u00fc\\u015fteri se\\u00e7ilmedi."); return; }
  const bugun = new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
  dkModal(`<div class="dk-det-head"><h3>Yeni Ziyaret \\u2014 ${esc(mus.firma || "")}</h3><button class="dk-x" data-kapat>\\u2715</button></div>
    <div class="dk-form2">
      <label>Ziyaret Tarihi *<input id="zy-tarih" type="date" value="${bugun}" max="${bugun}"></label>
      <label>Kat\\u0131l\\u0131mc\\u0131<input id="zy-kat" placeholder="G\\u00f6r\\u00fc\\u015f\\u00fclen ki\\u015fi (ops.)"></label>
    </div>
    <label class="dk-form-full" style="display:block;margin-top:6px">Ziyaret Notu<textarea id="zy-not" rows="5" placeholder="Ne konu\\u015fuldu, ne sat\\u0131ld\\u0131, sonraki ad\\u0131m..." style="width:100%;box-sizing:border-box;font:inherit"></textarea></label>
    <div class="dk-det-alt"><button class="dk-btn" data-kapat>Vazge\\u00e7</button><button class="dk-btn" id="zy-kaydet" style="background:#0ea5e9;color:#fff">Ziyareti Kaydet</button></div>`);
  const $ = id => S.container.querySelector("#" + id);
  $("zy-kaydet").addEventListener("click", async () => {
    const tarih = ($("zy-tarih").value || "").trim();
    if (!tarih) { alert("Ziyaret tarihi zorunlu."); return; }
    const btn = $("zy-kaydet"); const _t = btn.textContent; btn.disabled = true; btn.textContent = "Kaydediliyor...";
    try {
      const r = await api("/api/saha/ziyaretler", { method: "POST", body: JSON.stringify({ musteri_id: mus.id, tamamla: true, ziyaret_tarihi: tarih, katilimci: ($("zy-kat").value || "").trim() || null, notlar: ($("zy-not").value || "").trim() || null }) });
      dkKapat();
      if (r && r.mukerrer_engellendi) alert("Bu m\\u00fc\\u015fteriye az \\u00f6nce ayn\\u0131 g\\u00fcn ziyaret kaydedilmi\\u015f \\u2014 tekrar a\\u00e7\\u0131lmad\\u0131.");
      go("ziyaretler");
    } catch (e) { alert(e.message); btn.disabled = false; btn.textContent = _t; }
  });
}
'''
rep("function rowZiy(z) {", FUNC + "function rowZiy(z) {", "func")

open(F, "w", encoding="utf-8").write(s)
print("[done] YENI_ZIYARET_DESKTOP_V1")
