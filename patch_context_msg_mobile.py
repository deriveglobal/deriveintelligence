# -*- coding: utf-8 -*-
# CONTEXT_MSG_V1 (mobil) — musteri kartinda "💬 Mesaj" (sorumlu rep'e baglamli mesaj) + thread 🔗 rozeti.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "CONTEXT_MSG_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# M1) compose modal fonksiyonu + musteriDetayModal
OLD1 = "function musteriDetayModal(m) {"
NEW1 = """function musteriMesajModal(m) {  /* CONTEXT_MSG_V1 */
  modal(`<h3>💬 Rep'e Mesaj</h3>
    <div style="font-size:12px;color:#64748b;margin-bottom:8px">🔗 <b>${esc(m.firma)}</b> hakkında, sorumlu temsilciye</div>
    <textarea class="giris" id="cm-icerik" rows="4" placeholder="Mesajınız…" style="width:100%;box-sizing:border-box"></textarea>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button><button class="btn" id="cm-gonder">Gönder</button></div>`);
  document.getElementById("cm-gonder")?.addEventListener("click", async () => {
    const t = (document.getElementById("cm-icerik")?.value || "").trim();
    if (!t) return;
    const btn = document.getElementById("cm-gonder"); if (btn) { btn.disabled = true; btn.textContent = "Gönderiliyor…"; }
    try { await api(`/api/saha/musteri/${m.id}/mesaj`, { method: "POST", body: JSON.stringify({ icerik: t }) }); kapatModal(); uyari("✓ Mesaj sorumlu temsilciye gönderildi.", true); }
    catch (e) { uyari(e.message); if (btn) { btn.disabled = false; btn.textContent = "Gönder"; } }
  });
}
function musteriDetayModal(m) {"""
assert s.count(OLD1) == 1, "musteriDetayModal anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# M2) modal-btnlar'a Mesaj butonu
OLD2 = """    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn cizgili" id="md-planla">🗓️ Planla</button>
      <button class="btn cizgili" id="md-teklif">＋ Teklif</button>
      <button class="btn" id="md-ziyaret">＋ Ziyaret</button>
    </div>`);"""
NEW2 = """    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      ${["manager","admin"].includes(S.role) ? `<button class="btn cizgili" id="md-mesaj" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}
      <button class="btn cizgili" id="md-planla">🗓️ Planla</button>
      <button class="btn cizgili" id="md-teklif">＋ Teklif</button>
      <button class="btn" id="md-ziyaret">＋ Ziyaret</button>
    </div>`);"""
assert s.count(OLD2) == 1, "btnlar anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# M3) Mesaj butonu handler
OLD3 = '  document.getElementById("md-ziyaret")?.addEventListener("click", () => { kapatModal(); ziyaretFormModal(m, "kaydet"); });'
NEW3 = """  document.getElementById("md-ziyaret")?.addEventListener("click", () => { kapatModal(); ziyaretFormModal(m, "kaydet"); });
  document.getElementById("md-mesaj")?.addEventListener("click", () => { kapatModal(); musteriMesajModal(m); });  /* CONTEXT_MSG_V1 */"""
assert s.count(OLD3) == 1, "handler anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# M4) thread baloncuk 🔗 rozeti
OLD4 = 'white-space:pre-wrap">${esc(m.icerik)}</div>'
NEW4 = 'white-space:pre-wrap">${m.baglam_etiket ? `<div style="font-size:10px;opacity:.8;margin-bottom:3px">🔗 ${esc(m.baglam_etiket)}</div>` : ""}${esc(m.icerik)}</div>'
assert s.count(OLD4) == 1, "bubble anchor=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CONTEXT_MSG_V1 (mobil)")
