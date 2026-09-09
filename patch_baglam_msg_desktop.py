# -*- coding: utf-8 -*-
# BAGLAM_MSG_DK_V1 (masaustu) — teklif & ziyaret detayinda "💬 Mesaj" (o kaydin rep'ine, baglamli).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "BAGLAM_MSG_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# D1) ortak compose fonksiyonu (ziyaretDetay'dan once)
OLD1 = "async function ziyaretDetay(z) {"
NEW1 = """function baglamMesajDesktop(repId, etiket, baglamTip, baglamId) {  /* BAGLAM_MSG_DK_V1 */
  if (!repId) { alert("Bu kaydın sorumlu temsilcisi bulunamadı."); return; }
  dkModal(`<div class="dk-det-head"><h3>💬 Rep'e Mesaj</h3><button class="dk-x" data-kapat>✕</button></div>
    <div class="sub2" style="margin:2px 0 8px">🔗 <b>${esc(etiket)}</b> hakkında</div>
    <textarea id="bmd-icerik" rows="4" placeholder="Mesajınız…" style="width:100%;box-sizing:border-box;font:inherit;border:1px solid var(--cizgi);border-radius:8px;padding:9px"></textarea>
    <div class="dk-det-alt"><button class="dk-btn" data-kapat>Vazgeç</button><button class="dk-btn" id="bmd-gonder" style="background:#0284c7;color:#fff">Gönder</button></div>`);
  S.container.querySelector("#bmd-gonder")?.addEventListener("click", async () => {
    const t = (S.container.querySelector("#bmd-icerik")?.value || "").trim(); if (!t) return;
    const btn = S.container.querySelector("#bmd-gonder"); if (btn) { btn.disabled = true; btn.textContent = "Gönderiliyor…"; }
    try { await api(`/api/saha/baglamli-mesaj`, { method: "POST", body: JSON.stringify({ rep_id: repId, icerik: t, baglam_tip: baglamTip, baglam_id: baglamId, baglam_etiket: etiket }) }); dkKapat(); alert("✓ Mesaj temsilciye gönderildi."); }
    catch (e) { alert(e.message); if (btn) { btn.disabled = false; btn.textContent = "Gönder"; } }
  });
}
async function ziyaretDetay(z) {"""
assert s.count(OLD1) == 1, "helper anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# D2) TEKLIF footer butonu
OLD2 = '    <div class="dk-det-alt">${foot.join("")}<button class="dk-btn" data-kapat>Kapat</button></div>`);'
NEW2 = '    <div class="dk-det-alt">${S.role !== "rep" ? `<button class="dk-btn" id="td-mesaj" data-rep="${esc(t.rep_id || "")}" data-firma="${esc(t.firma || "")}" data-tid="${esc(t.id)}" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}${foot.join("")}<button class="dk-btn" data-kapat>Kapat</button></div>`);  /* BAGLAM_MSG_DK_V1 */'
assert s.count(OLD2) == 1, "teklif-foot anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# D3) TEKLIF handler (TEKLIF_KARAR_V1 yorumundan once)
OLD3 = "  // TEKLIF_KARAR_V1 — owner: rep fiyati vs sistem onerisi + saglik isigi"
NEW3 = """  S.container.querySelector("#td-mesaj")?.addEventListener("click", (ev) => { const b = ev.currentTarget; baglamMesajDesktop(b.dataset.rep, (b.dataset.firma || "") + " teklifi", "teklif", b.dataset.tid); });  /* BAGLAM_MSG_DK_V1 */
  // TEKLIF_KARAR_V1 — owner: rep fiyati vs sistem onerisi + saglik isigi"""
assert s.count(OLD3) == 1, "teklif-handler anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# D4) ZIYARET head butonu
OLD4 = """      <span class="pill ${z.tip === "TUKETICI" ? "p-info" : "p-mut"}">${z.tip === "TUKETICI" ? "Tüketici" : "Ticari"}</span>
      <button class="dk-x" data-kapat title="Kapat">✕</button>
    </div>"""
NEW4 = """      <span class="pill ${z.tip === "TUKETICI" ? "p-info" : "p-mut"}">${z.tip === "TUKETICI" ? "Tüketici" : "Ticari"}</span>
      <button class="dk-x" data-kapat title="Kapat">✕</button>
    </div>
    ${S.role !== "rep" && z.rep_id ? `<div style="margin:8px 0"><button class="dk-btn dk-btn-sm" id="zd-mesaj" data-rep="${esc(z.rep_id)}" data-firma="${esc(z.firma || "")}" data-zid="${esc(z.id)}" style="border-color:#0284c7;color:#0284c7">💬 Rep'e Mesaj</button></div>` : ""}"""
assert s.count(OLD4) == 1, "ziyaret-head anchor=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

# D5) ZIYARET handler (otomatik gorudum yorumundan once)
OLD5 = '  // otomatik "görüldüm" + görenler'
NEW5 = """  S.container.querySelector("#zd-mesaj")?.addEventListener("click", (ev) => { const b = ev.currentTarget; baglamMesajDesktop(b.dataset.rep, (b.dataset.firma || "") + " ziyareti", "ziyaret", b.dataset.zid); });  /* BAGLAM_MSG_DK_V1 */
  // otomatik "görüldüm" + görenler"""
assert s.count(OLD5) == 1, "ziyaret-handler anchor=%d" % s.count(OLD5)
s = s.replace(OLD5, NEW5, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BAGLAM_MSG_DK_V1")
