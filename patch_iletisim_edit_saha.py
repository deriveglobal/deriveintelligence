import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "ILETISIM_EDIT_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert s.count(old) == 1, "anchor %s count=%d" % (tag, s.count(old))
    s = s.replace(old, new, 1); print("[ok]", tag)

# 1) Yetkili + Telefon satirlarini SALT-OKUNUR yerine DUZENLENEBILIR input + Kaydet yap
OLD = (
'    ${m.yetkili ? `<div class="det-satir"><span>Yetkili</span><b>${esc(m.yetkili)}</b></div>` : ""}\n'
'    ${m.telefon ? `<div class="det-satir"><span>Telefon</span><b><a href="tel:${esc(m.telefon)}">${esc(m.telefon)}</a></b></div>` : ""}'
)
NEW = (
'    <div class="det-satir"><span>Yetkili</span><input class="giris" id="md-yetkili" placeholder="Ad Soyad / Ünvan" value="${esc(m.yetkili || "")}" style="font-size:13px;padding:4px 8px;width:auto;margin-bottom:0"></div><!-- ILETISIM_EDIT_V1 -->\n'
'    <div class="det-satir"><span>Telefon</span><span style="display:flex;gap:5px;align-items:center"><input class="giris" id="md-tel" inputmode="tel" placeholder="+90 5xx xxx xx xx" value="${esc(m.telefon || "")}" style="font-size:13px;padding:4px 8px;width:auto;margin-bottom:0"><button class="btn kucuk" id="md-iletisim-kaydet">Kaydet</button></span></div>'
)
rep(OLD, NEW, "satir")

# 2) Kaydet handler'ini (md-erp-ara wiring'inden hemen once) ekle
ANCHOR = '  // VKN_ESLESME_V1 — "ERP\'de Ara": VKN ile SAP carisi bul & otomatik bağla (sadece ERP\'siz müşteride)'
HANDLER = (
'  document.getElementById("md-iletisim-kaydet")?.addEventListener("click", async () => {  /* ILETISIM_EDIT_V1 */\n'
'    const yk = (document.getElementById("md-yetkili")?.value || "").trim();\n'
'    const tl = (document.getElementById("md-tel")?.value || "").trim();\n'
'    const btn = document.getElementById("md-iletisim-kaydet"); const _t = btn ? btn.textContent : "";\n'
'    if (btn) { btn.disabled = true; btn.textContent = "..."; }\n'
'    try {\n'
'      await api(`/api/saha/musteriler/${m.id}`, { method: "PUT", body: JSON.stringify({ yetkili: yk || null, telefon: tl || null }) });\n'
'      m.yetkili = yk || null; m.telefon = tl || null;\n'
'      uyari("✓ İletişim güncellendi.", true);\n'
'    } catch (e) { uyari(e.message); }\n'
'    if (btn) { btn.disabled = false; btn.textContent = _t; }\n'
'  });\n'
)
rep(ANCHOR, HANDLER + ANCHOR, "wire")

open(F, "w", encoding="utf-8").write(s)
print("[done] ILETISIM_EDIT_V1")
