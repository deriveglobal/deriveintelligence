# -*- coding: utf-8 -*-
# CONTEXT_MSG_DK2_V1 (masaustu) — musteri kartinda "💬 Mesaj" (sorumlu rep'e baglamli mesaj).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "CONTEXT_MSG_DK2_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# D1) compose fonksiyonu + musteriDetay
OLD1 = "async function musteriDetay(m) {"
NEW1 = """function musteriMesajDesktop(m) {  /* CONTEXT_MSG_DK2_V1 */
  dkModal(`<div class="dk-det-head"><h3>💬 Rep'e Mesaj</h3><button class="dk-x" data-kapat>✕</button></div>
    <div class="sub2" style="margin:2px 0 8px">🔗 <b>${esc(m.firma)}</b> hakkında, sorumlu temsilciye</div>
    <textarea id="cmd-icerik" rows="4" placeholder="Mesajınız…" style="width:100%;box-sizing:border-box;font:inherit;border:1px solid var(--cizgi);border-radius:8px;padding:9px"></textarea>
    <div class="dk-det-alt"><button class="dk-btn" data-kapat>Vazgeç</button><button class="dk-btn" id="cmd-gonder" style="background:#0284c7;color:#fff">Gönder</button></div>`);
  S.container.querySelector("#cmd-gonder")?.addEventListener("click", async () => {
    const t = (S.container.querySelector("#cmd-icerik")?.value || "").trim();
    if (!t) return;
    const btn = S.container.querySelector("#cmd-gonder"); if (btn) { btn.disabled = true; btn.textContent = "Gönderiliyor…"; }
    try { await api(`/api/saha/musteri/${m.id}/mesaj`, { method: "POST", body: JSON.stringify({ icerik: t }) }); dkKapat(); alert("✓ Mesaj sorumlu temsilciye gönderildi."); }
    catch (e) { alert(e.message); if (btn) { btn.disabled = false; btn.textContent = "Gönder"; } }
  });
}
async function musteriDetay(m) {"""
assert s.count(OLD1) == 1, "musteriDetay anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# D2) aksiyon satirina buton
OLD2 = '    <div class="dk-det-alt">${yol ? `<button class="dk-btn" id="md-yol">🧭 Yol Tarifi</button>` : ""}<button class="dk-btn" data-kapat>Kapat</button></div>`);'
NEW2 = '    <div class="dk-det-alt">${isMgmt ? `<button class="dk-btn" id="md-mesaj" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}${yol ? `<button class="dk-btn" id="md-yol">🧭 Yol Tarifi</button>` : ""}<button class="dk-btn" data-kapat>Kapat</button></div>`);  /* CONTEXT_MSG_DK2_V1 */'
assert s.count(OLD2) == 1, "action anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# D3) handler
OLD3 = '  if (yol) S.container.querySelector("#md-yol").addEventListener("click", () => window.open(`https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}`, "_blank"));'
NEW3 = """  if (yol) S.container.querySelector("#md-yol").addEventListener("click", () => window.open(`https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}`, "_blank"));
  S.container.querySelector("#md-mesaj")?.addEventListener("click", () => musteriMesajDesktop(m));  /* CONTEXT_MSG_DK2_V1 */"""
assert s.count(OLD3) == 1, "handler anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CONTEXT_MSG_DK2_V1")
