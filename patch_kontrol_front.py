# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# KONTROL_FRONT — rep customer tab: "Kontrol Bekleyen" panel for EXCEL_IMPORT_KONTROL
# customers, with Birleştir (pick existing via musteriSecModal) / Yeni müşteri actions.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) add the panel container (visible to reps too)
rep(
'''    <button class="saha-cta" id="yeni-musteri">＋ Müşteri</button>
    ${S.role !== "rep" ? `<div id="bakim-paneli"></div>` : ""}''',
'''    <button class="saha-cta" id="yeni-musteri">＋ Müşteri</button>
    <div id="kontrol-paneli"></div>
    ${S.role !== "rep" ? `<div id="bakim-paneli"></div>` : ""}''',
    "panel-html")

# 2) load it
rep(
'  if (S.role !== "rep") bakimPaneliYukle();',
'  if (S.role !== "rep") bakimPaneliYukle();\n  kontrolPaneliYukle();',
    "panel-load")

# 3) the function (inserted before bakimPaneliYukle)
rep(
"async function bakimPaneliYukle() {",
'''async function kontrolPaneliYukle() {
  const box = document.getElementById("kontrol-paneli");
  if (!box) return;
  let list = [];
  try { list = (await api("/api/saha/kontrol-musteriler")).musteriler || []; } catch { box.innerHTML = ""; return; }
  if (!list.length) { box.innerHTML = ""; return; }
  box.innerHTML = `
    <div style="background:#fffbeb;border:1px solid #fcd34d;border-radius:10px;padding:10px 12px;margin:8px 0">
      <div style="font-weight:700;color:#92400e;font-size:13px;margin-bottom:4px">🔎 Kontrol Bekleyen Müşteri (${list.length})</div>
      <div style="font-size:11px;color:#b45309;margin-bottom:8px">Excel'den gelen bu kayıtlar mevcut bir müşteriyle aynı olabilir. Karar ver:</div>
      ${list.map(m => `
        <div class="kart" style="margin-bottom:6px;padding:8px 10px;background:#fff">
          <div style="font-weight:600">${esc(m.firma)} <span style="color:#94a3b8;font-size:11px">· ${m.ziyaret_sayisi} ziyaret</span></div>
          ${m.notlar ? `<div style="font-size:11px;color:#64748b;margin:3px 0">${esc(m.notlar)}</div>` : ""}
          <div style="display:flex;gap:6px;margin-top:6px">
            <button class="btn" data-kb="${m.id}" style="font-size:12px;padding:5px 10px">🔗 Mevcutla birleştir</button>
            <button class="btn cizgili" data-ky="${m.id}" style="font-size:12px;padding:5px 10px">✓ Yeni müşteri</button>
          </div>
        </div>`).join("")}
    </div>`;
  box.querySelectorAll("[data-ky]").forEach(b => b.addEventListener("click", async () => {
    if (!confirm("Bu kayıt YENİ müşteri olarak onaylansın mı?")) return;
    try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: b.dataset.ky, karar: "YENI" }) }); uyari("✓ Yeni müşteri olarak onaylandı.", true); kontrolPaneliYukle(); }
    catch (e) { uyari(e.message); }
  }));
  box.querySelectorAll("[data-kb]").forEach(b => b.addEventListener("click", () => {
    const kid = b.dataset.kb;
    musteriSecModal(async target => {
      if (!target || target.id === kid) { uyari("Farklı, mevcut bir müşteri seç."); return; }
      try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "BIRLESTIR", hedef_id: target.id }) }); uyari("✓ Birleştirildi.", true); await loadView("musteriler"); }
      catch (e) { uyari(e.message); }
    });
  }));
}

async function bakimPaneliYukle() {''',
    "panel-fn")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
