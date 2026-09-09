# -*- coding: utf-8 -*-
# YAYIM_OKUYAN_DK_V1 (masaustu) — Hızlı Duyuru modalinde "kim gördü (saatiyle) / kim görmedi".
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "YAYIM_OKUYAN_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '''    dkModal(`<div class="dk-det-head"><h3>📣 Hızlı Duyuru</h3><button class="dk-x" data-kapat>✕</button></div>
      <div class="sub2" style="margin:2px 0 8px">${_dkKisaTs(y.created_at)}${y.gonderen_adi ? " · " + esc(y.gonderen_adi) : ""}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""} okudu`:""}</div>
      <div style="white-space:pre-wrap;font-size:14px;line-height:1.6">${esc(y.icerik)}</div>
      <div class="dk-det-alt"><button class="dk-btn" data-kapat>Kapat</button></div>`);'''
NEW = '''    dkModal(`<div class="dk-det-head"><h3>📣 Hızlı Duyuru</h3><button class="dk-x" data-kapat>✕</button></div>
      <div class="sub2" style="margin:2px 0 8px">${_dkKisaTs(y.created_at)}${y.gonderen_adi ? " · " + esc(y.gonderen_adi) : ""}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""} gördü`:""}</div>
      <div style="white-space:pre-wrap;font-size:14px;line-height:1.6">${esc(y.icerik)}</div>
      <div id="yyd-okuyan" class="sub2" style="margin-top:12px;background:var(--gri-z,#f8fafc);border-radius:8px;padding:9px 11px;line-height:1.7">Kim gördü yükleniyor…</div>
      <div class="dk-det-alt"><button class="dk-btn" data-kapat>Kapat</button></div>`);
    (async () => {  /* YAYIM_OKUYAN_DK_V1 */
      try {
        const r = await api("/api/saha/yayim-okuyanlar", { method: "POST", body: JSON.stringify({ icerik: y.icerik }) });
        const box = S.container.querySelector("#yyd-okuyan"); if (!box) return;
        const ok = (r.okuyanlar || []).map(x => esc(x.ad) + (x.okundu_at ? ` <span style="color:#94a3b8">(${_dkKisaTs(x.okundu_at)})</span>` : "")).join("<br>");
        const no = (r.okumayanlar || []).map(x => esc(x)).join(", ");
        box.innerHTML = `<div style="margin-bottom:6px"><b style="color:var(--mavi)">✓ Gördü (${(r.okuyanlar || []).length}):</b><br>${ok || "—"}</div><div><b style="color:#94a3b8">Görmedi (${(r.okumayanlar || []).length}):</b> ${no || "—"}</div>`;
      } catch (e) { const box = S.container.querySelector("#yyd-okuyan"); if (box) box.textContent = ""; }
    })();'''
assert s.count(OLD) == 1, "modal anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_OKUYAN_DK_V1 (masaustu)")
