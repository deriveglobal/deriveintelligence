# -*- coding: utf-8 -*-
# RAPOR_SEGMENT_DK_V1 (masaustu) — Temsilci Performansi tablosuna Segment rozeti.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_SEGMENT_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) yardimci fonksiyon + rpTemsilciler
HELPER_ANCHOR = """  async function rpTemsilciler() {
    const el = icerik(); if (!el) return; el.innerHTML = load();"""
HELPER = """  function _rpSegDk(r){  /* RAPOR_SEGMENT_DK_V1 — admin saha_tip -> yoksa ziyaret cogunlugundan turet */
    const a = String(r.saha_tip || "").toUpperCase();
    let t, solid = false;
    if (a === "TUKETICI") { t = "Tüketici"; solid = true; }
    else if (a === "TICARI") { t = "Ticari"; solid = true; }
    else {
      const tk = Number(r.tuketici_z) || 0, tc = Number(r.ticari_z) || 0, tot = tk + tc;
      if (!tot) return `<span style="color:var(--tx-3,#cbd5e1)">—</span>`;
      const sh = Math.max(tk, tc) / tot;
      t = sh < 0.65 ? "Karma" : (tk >= tc ? "Tüketici" : "Ticari");
    }
    const col = t === "Tüketici" ? "#0ea5e9" : t === "Ticari" ? "#f59e0b" : "#8b5cf6";
    const st = solid ? `background:${col};color:#fff;` : `background:${col}1a;color:${col};border:1px solid ${col}55;`;
    const tip = solid ? "Yönetici atadı" : "Ziyaretlerden türetildi";
    return `<span title="${tip}" style="display:inline-block;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:700;white-space:nowrap;${st}">${t}${solid ? "" : " ~"}</span>`;
  }
  async function rpTemsilciler() {
    const el = icerik(); if (!el) return; el.innerHTML = load();"""
assert s.count(HELPER_ANCHOR) == 1, "dk helper anchor=%d" % s.count(HELPER_ANCHOR)
s = s.replace(HELPER_ANCHOR, HELPER, 1)

# 2) baslik
TH_OLD = '<thead><tr><th>Temsilci</th><th>Ziyaret</th><th class="num">Müşteri</th><th class="num">Teklif</th><th class="num">Win %</th></tr></thead>'
TH_NEW = '<thead><tr><th>Temsilci</th><th>Segment</th><th>Ziyaret</th><th class="num">Müşteri</th><th class="num">Teklif</th><th class="num">Win %</th></tr></thead>'
assert s.count(TH_OLD) == 1, "dk th anchor=%d" % s.count(TH_OLD)
s = s.replace(TH_OLD, TH_NEW, 1)

# 3) govde — isim td'sinden sonra segment td'si
TD_OLD = """      return `<tr>
              <td class="firm">${esc(r.rep)}</td>"""
TD_NEW = """      return `<tr>
              <td class="firm">${esc(r.rep)}</td>
              <td>${_rpSegDk(r)}</td>"""
assert s.count(TD_OLD) == 1, "dk td anchor=%d" % s.count(TD_OLD)
s = s.replace(TD_OLD, TD_NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_SEGMENT_DK_V1 (masaustu)")
