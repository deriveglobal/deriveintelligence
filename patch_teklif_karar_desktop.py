# -*- coding: utf-8 -*-
# TEKLIF_KARAR_V1 (masaustu) — owner onay ekraninda: rep fiyati vs SISTEM onerisi + saglik.
#   Yalniz ONAY_BEKLIYOR + owner (S.role !== "rep"). Rep tarafi HIC degismez.
#   Her kalem icin /api/bi/teklif-oneri (marka+ebat+fiyat) cagrilir; kalemler'de kalem_kodu
#   yok ama marka/ebat var -> uc bunu SKU'ya cozer (TEKLIF_ONERI_V2).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "TEKLIF_KARAR_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) Konteyner — kalem tablosundan sonra, esik satirindan once (owner + ONAY_BEKLIYOR)
OLD1 = '''    ${kalemHtml}
    ${t.durum === "ONAY_BEKLIYOR" ? `<div class="dk-esik"'''
NEW1 = '''    ${kalemHtml}
    ${(t.durum === "ONAY_BEKLIYOR" && S.role !== "rep") ? `<div class="dk-det-yh" style="margin-top:14px">🧭 Sistem Önerisi — Rep vs Sistem</div><div id="td-oneri" class="sub2">Yükleniyor…</div>` : ""}<!-- TEKLIF_KARAR_V1 -->
    ${t.durum === "ONAY_BEKLIYOR" ? `<div class="dk-esik"'''
assert s.count(OLD1) == 1, "OLD1 anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) Async doldurucu — log IIFE'sinden hemen once
OLD2 = '''  (async () => {
    try {
      const { log = [] } = await api(`/api/saha/teklifler/${t.id}/log`);'''
NEW2 = '''  // TEKLIF_KARAR_V1 — owner: rep fiyati vs sistem onerisi + saglik isigi
  if (t.durum === "ONAY_BEKLIYOR" && S.role !== "rep") (async () => {
    const box = S.container.querySelector("#td-oneri"); if (!box) return;
    const mid = t.musteri_id || t.musteri || null;
    const tl = v => `₺${Number(v).toLocaleString("tr-TR")}`;
    const out = [];
    for (const k of kalemler) {
      const marka = (k.marka || "").trim(), ebat = (k.ebat || "").trim();
      if (!marka || !ebat) continue;
      try {
        const q = new URLSearchParams({ marka, ebat });
        if (k.birim_fiyat != null) q.set("fiyat", String(k.birim_fiyat));
        if (mid) q.set("musteri_id", mid);
        const r = await api(`/api/bi/teklif-oneri?${q.toString()}`);
        if (!r || !r.veri) { out.push(`<div class="dk-log"><b>${esc(marka)} ${esc(ebat)}</b> · <span class="sub2">öneri yok</span></div>`); continue; }
        const dot = r.saglik === "kirmizi" ? "🔴" : r.saglik === "amber" ? "🟡" : r.saglik === "yesil" ? "🟢" : "⚪";
        const rep = k.birim_fiyat != null ? tl(k.birim_fiyat) : "—";
        const sis = r.oneri != null ? tl(r.oneri) : "—";
        const marj = r.rep_marj != null ? ` · rep marj <b>%${r.rep_marj}</b>` : "";
        const rakip = r.rakip && r.rakip.fiyat ? ` · ⚔ ${esc(r.rakip.marka || "rakip")} ${tl(r.rakip.fiyat)}` : "";
        const pz = (r.piyasa && r.piyasa.med != null) ? ` · piyasa ${tl(r.piyasa.med)}` : "";
        out.push(`<div class="dk-log">${dot} <b>${esc(marka)} ${esc(ebat)}</b> · rep <b>${rep}</b> vs sistem <b style="color:var(--mavi)">${sis}</b>${marj}${rakip}${pz}</div>`);
      } catch (e) { out.push(`<div class="dk-log sub2">${esc(marka)} ${esc(ebat)} · okunamadı</div>`); }
    }
    box.classList.remove("sub2");
    box.innerHTML = out.length ? out.join("") : `<div class="sub2">Fiyatlanacak kalem eşleşmedi.</div>`;
  })();
  (async () => {
    try {
      const { log = [] } = await api(`/api/saha/teklifler/${t.id}/log`);'''
assert s.count(OLD2) == 1, "OLD2 anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] TEKLIF_KARAR_V1 (masaustu)")
