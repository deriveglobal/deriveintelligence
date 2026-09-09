# -*- coding: utf-8 -*-
# MUSTERI_ATAMA_V1 (Yonetim konsolu) — tenant-admin.js: "Müşteri Atama" bolumu.
#   Nav (saha-gated) + renderView map + renderMusteriAtama (tablo/filtre/tekil+toplu ata/gecmis).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "MUSTERI_ATAMA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) nav — saha bloguna "Müşteriler" etiketi + Atama butonu
o1 = '        ${subModules().includes("saha") ? `<div class="ta-nav-label">Denetim</div>'
n1 = ('        ${subModules().includes("saha") ? `<div class="ta-nav-label">Müşteriler</div>\n'
      '        ${navBtn("musteri-atama", "Atama", \'<path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/>\')}  <!-- MUSTERI_ATAMA_V1 -->\n'
      '        <div class="ta-nav-label">Denetim</div>')
assert s.count(o1) == 1, "nav anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) renderView map
o2 = '      invite: ["Davet Et", "Yeni kullanıcı davet bağlantısı", renderInvite],'
n2 = o2 + '\n      "musteri-atama": ["Müşteri Atama", "Sorumlu temsilci ataması — mevcut varsayılan, değiştirilebilir", renderMusteriAtama],  /* MUSTERI_ATAMA_V1 */'
assert s.count(o2) == 1, "map anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) renderMusteriAtama — İzinler bolumunden once
anchor = '  // ─── İzinler — unified editable access matrix ───────────────────────────────'
BLOCK = r'''  // ─── Müşteri Atama (MUSTERI_ATAMA_V1) ───────────────────────────────────────
  const ATA = { data: null, sel: new Set(), q: "", rep: "", tip: "", loaded: false };
  const ataKisa = (n) => { n = Math.round(Number(n) || 0); if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + n; };
  async function renderMusteriAtama(content, actions) {
    if (!ATA.loaded) { content.innerHTML = `<div class="ta-loading"><div class="ta-spin"></div>Yükleniyor…</div>`; ATA.data = await apiFetch("/api/tenant/musteri-atama"); ATA.loaded = true; }
    const reps = (ATA.data && ATA.data.temsilciler) || [];
    actions.innerHTML = `<input class="ta-input ta-atainp" id="ata-q" placeholder="Firma / il ara…" value="${esc(ATA.q)}">
      <select class="ta-input ta-atainp" id="ata-rep"><option value="">Tüm temsilciler</option><option value="__none__"${ATA.rep === "__none__" ? " selected" : ""}>Atanmamış</option>${reps.map(r => `<option value="${esc(r.id)}"${ATA.rep === r.id ? " selected" : ""}>${esc(r.ad)}</option>`).join("")}</select>
      <select class="ta-input ta-atainp" id="ata-tip"><option value="">Tüm tipler</option><option value="TUKETICI"${ATA.tip === "TUKETICI" ? " selected" : ""}>Toptan (PSR)</option><option value="TICARI"${ATA.tip === "TICARI" ? " selected" : ""}>Filo (TBR-OTR)</option></select>`;
    const qEl = actions.querySelector("#ata-q");
    qEl.oninput = () => { ATA.q = qEl.value; drawAtamaBody(content); const el = actions.querySelector("#ata-q"); };
    actions.querySelector("#ata-rep").onchange = (e) => { ATA.rep = e.target.value; drawAtamaBody(content); };
    actions.querySelector("#ata-tip").onchange = (e) => { ATA.tip = e.target.value; drawAtamaBody(content); };
    drawAtamaBody(content);
  }
  function drawAtamaBody(content) {
    const reps = (ATA.data && ATA.data.temsilciler) || [], all = (ATA.data && ATA.data.musteriler) || [];
    const repName = {}; reps.forEach(r => repName[r.id] = r.ad);
    const atanmamis = all.filter(m => !m.rep_id).length;
    const q = ATA.q.trim().toLowerCase();
    let rows = all.filter(m => {
      if (ATA.rep === "__none__") { if (m.rep_id) return false; } else if (ATA.rep && m.rep_id !== ATA.rep) return false;
      if (ATA.tip && m.tip !== ATA.tip) return false;
      if (q && !((m.firma || "").toLowerCase().includes(q) || (m.il || "").toLowerCase().includes(q))) return false;
      return true;
    });
    const cap = 400, shown = rows.slice(0, cap);
    const tipBadge = (t) => t === "TUKETICI" ? `<span class="ta-badge ta-badge-member">Toptan</span>` : t === "TICARI" ? `<span class="ta-badge ta-badge-admin">Filo</span>` : `<span class="ta-muted">—</span>`;
    const selN = ATA.sel.size;
    const bulk = `<div class="ta-atabar${selN ? " on" : ""}"><span><b>${selN}</b> müşteri seçili</span><select class="ta-input ta-atainp" id="ata-bulk-rep"><option value="">Temsilci seç…</option>${reps.map(r => `<option value="${esc(r.id)}">${esc(r.ad)}</option>`).join("")}</select><button class="ta-btn ta-btn-primary ta-btn-xs" id="ata-bulk-go">Seçilenleri ata</button><button class="ta-btn ta-btn-xs" id="ata-bulk-clear">Temizle</button></div>`;
    const rowsHtml = shown.map(m => `<tr data-mid="${esc(m.id)}">
      <td><input type="checkbox" class="ata-cb" data-mid="${esc(m.id)}"${ATA.sel.has(m.id) ? " checked" : ""}></td>
      <td><div class="ta-user-nm">${esc(m.firma)}</div><div class="ta-user-em">${esc(m.il || "—")}${m.ilce ? " · " + esc(m.ilce) : ""}</div></td>
      <td>${tipBadge(m.tip)}</td>
      <td class="ta-muted">${m.segment ? esc(m.segment) : "—"}</td>
      <td class="ata-rep-cell">${m.rep ? esc(m.rep) : `<b style="color:#c0392b">atanmamış</b>`}</td>
      <td class="ta-muted">${m.gun == null ? "hiç" : m.gun + "g"}</td>
      <td class="ta-muted">${m.kod ? ataKisa(m.ciro) : "—"}</td>
      <td class="ta-act"><button class="ta-btn ta-btn-xs" data-degis="${esc(m.id)}">Değiştir</button> <button class="ta-btn ta-btn-xs ta-btn-secondary" data-gecmis="${esc(m.id)}">Geçmiş</button></td>
    </tr>`).join("");
    content.innerHTML = `<style>.ta-atainp{width:auto;display:inline-block;min-width:150px;padding:8px 11px;font-size:13px;margin-left:6px}
      .ta-atabar{display:none;align-items:center;gap:10px;background:#eef3ff;border:1px solid #cddaf5;border-radius:10px;padding:9px 13px;margin-bottom:12px;font-size:13px}.ta-atabar.on{display:flex}
      .ata-stat{font-size:13px;color:#5a6172;margin-bottom:10px}.ata-stat b{color:#12182a}
      .ata-gecrow td{background:#fafbfe;font-size:12.5px;color:#5a6172;padding:6px 12px}.ata-gecrow .g{padding:3px 0}.ata-gecrow b{color:#12182a}
      .ta-input.ta-inp-sm{width:auto;min-width:150px;padding:6px 9px;font-size:13px;display:inline-block}</style>
      <div class="ata-stat">Toplam <b>${all.length}</b> müşteri · <b style="color:#c0392b">${atanmamis}</b> atanmamış${rows.length > cap ? ` · gösterilen ilk <b>${cap}</b> / ${rows.length} (aramayla daralt)` : ` · gösterilen <b>${shown.length}</b>`}</div>
      ${bulk}
      <div class="ta-tablewrap"><table class="ta-table"><thead><tr><th style="width:28px"><input type="checkbox" id="ata-all"></th><th>Firma</th><th>Tip</th><th>Segment</th><th>Sorumlu</th><th>Son ziy.</th><th>12a ciro</th><th>İşlem</th></tr></thead><tbody>${rowsHtml || `<tr><td colspan="8" class="ta-empty-sm">Eşleşen müşteri yok.</td></tr>`}</tbody></table></div>`;
    content.querySelectorAll(".ata-cb").forEach(cb => cb.onchange = () => { if (cb.checked) ATA.sel.add(cb.dataset.mid); else ATA.sel.delete(cb.dataset.mid); drawAtamaBody(content); });
    const allcb = content.querySelector("#ata-all"); if (allcb) allcb.onchange = () => { shown.forEach(m => { if (allcb.checked) ATA.sel.add(m.id); else ATA.sel.delete(m.id); }); drawAtamaBody(content); };
    const go = content.querySelector("#ata-bulk-go"); if (go) go.onclick = async () => { const rep = content.querySelector("#ata-bulk-rep").value; if (!rep) { toast("Temsilci seç", "err"); return; } const ids = [...ATA.sel]; if (!ids.length) return; if (!(await taConfirm(`${ids.length} müşteriyi "${repName[rep] || ""}" temsilcisine ata?`, "Ata"))) return; ataPost(ids, rep, content); };
    const clr = content.querySelector("#ata-bulk-clear"); if (clr) clr.onclick = () => { ATA.sel.clear(); drawAtamaBody(content); };
    content.querySelectorAll("[data-degis]").forEach(b => b.onclick = () => {
      const mid = b.dataset.degis, tr = b.closest("tr"), cell = tr.querySelector(".ata-rep-cell"), m = all.find(x => x.id === mid);
      cell.innerHTML = `<select class="ta-input ta-inp-sm" data-sel>${reps.map(r => `<option value="${esc(r.id)}"${m && m.rep_id === r.id ? " selected" : ""}>${esc(r.ad)}</option>`).join("")}</select> <button class="ta-btn ta-btn-xs ta-btn-primary" data-ok>✓ Kaydet</button> <button class="ta-btn ta-btn-xs" data-no>Vazgeç</button>`;
      cell.querySelector("[data-ok]").onclick = () => { const rep = cell.querySelector("[data-sel]").value; ataPost([mid], rep, content); };
      cell.querySelector("[data-no]").onclick = () => drawAtamaBody(content);
    });
    content.querySelectorAll("[data-gecmis]").forEach(b => b.onclick = () => ataGecmis(b.dataset.gecmis, b.closest("tr")));
  }
  async function ataPost(ids, hedef_rep, content) {
    try {
      const r = await apiFetch("/api/tenant/musteri-atama", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ musteri_ids: ids, hedef_rep }) });
      toast((r.degisen || 0) + " müşteri güncellendi", "ok");
      ATA.loaded = false; ATA.sel.clear();
      await renderMusteriAtama(document.getElementById("ta-content"), document.getElementById("ta-header-actions"));
    } catch (e) { toast("Hata: " + e.message, "err"); }
  }
  async function ataGecmis(mid, tr) {
    const nx = tr.nextElementSibling;
    if (nx && nx.classList.contains("ata-gecrow")) { nx.remove(); return; }
    let body = `<div class="g ta-muted">Yükleniyor…</div>`;
    const row = document.createElement("tr"); row.className = "ata-gecrow"; row.innerHTML = `<td colspan="8">${body}</td>`;
    tr.after(row);
    try {
      const d = await apiFetch("/api/tenant/musteri-atama/gecmis?musteri_id=" + encodeURIComponent(mid));
      const g = d.gecmis || [];
      body = g.length ? g.map(x => `<div class="g"><b>${new Date(x.ts).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" })}</b> — ${esc(x.aktor || "—")}: ${esc(x.eski || "—")} → <b>${esc(x.yeni || "—")}</b></div>`).join("") : `<div class="g ta-muted">Henüz atama değişikliği yok — ilk sahip Excel ziyaret defterinden geldi.</div>`;
      row.innerHTML = `<td colspan="8"><div style="font-weight:700;color:#12182a;margin-bottom:4px">📜 Atama geçmişi</div>${body}</td>`;
    } catch (e) { row.innerHTML = `<td colspan="8"><div class="g" style="color:#c0392b">Geçmiş yüklenemedi: ${esc(e.message)}</div></td>`; }
  }

''' + anchor
assert s.count(anchor) == 1, "izinler anchor=%d" % s.count(anchor)
s = s.replace(anchor, BLOCK, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_ATAMA_V1 (konsol) — nav + map + render")
