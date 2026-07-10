# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# DUYURU_BOARD_V1 (front) — everyone sees the post button; Duyuru/Piyasa selector
# + tip badges on cards and detail.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) post button visible to everyone
rep('      ${isYonetici ? `<button class="saha-cta" id="yeni-duyuru">📢 Yeni Duyuru</button>` : ""}',
    '      <button class="saha-cta" id="yeni-duyuru">📢 Yeni Paylaşım</button>',
    "button-all")

# 2) tip badge on card (before onem badge)
rep('              ${d.onem !== "NORMAL" ? `<span class="rozet" style="background:${onemRenk[d.onem]}">${onemEtiket[d.onem]}</span>` : ""}',
    '              ${d.tip === "PIYASA" ? `<span class="rozet" style="background:#0891b2">📊 Piyasa</span>` : ""}${d.onem !== "NORMAL" ? `<span class="rozet" style="background:${onemRenk[d.onem]}">${onemEtiket[d.onem]}</span>` : ""}',
    "card-badge")

# 3) yeniDuyuruModal: title + tip selector
rep('''  modal(`
    <h3>Yeni Duyuru</h3>
    <label class="etiket">Başlık *</label>''',
    '''  modal(`
    <h3>Yeni Paylaşım</h3>
    <label class="etiket">Tür</label>
    <select id="dy-tip" class="giris">
      <option value="DUYURU">📢 Duyuru</option>
      <option value="PIYASA">📊 Piyasa Bilgisi</option>
    </select>
    <label class="etiket">Başlık *</label>''',
    "modal-tip")

# 4) send tip in POST
rep('      await api("/api/saha/duyurular", { method: "POST", body: JSON.stringify({ baslik, icerik, onem }) });',
    '      const tip = document.getElementById("dy-tip")?.value || "DUYURU";\n      await api("/api/saha/duyurular", { method: "POST", body: JSON.stringify({ baslik, icerik, onem, tip }) });',
    "post-tip")

# 5) tip badge in detail modal
rep('        ${d.onem !== "NORMAL" ? `<span class="rozet" style="background:${onemRenk[d.onem]}">${d.onem === "ACIL" ? "🚨 Acil" : "⚠️ Önemli"}</span>` : ""}',
    '        ${d.tip === "PIYASA" ? `<span class="rozet" style="background:#0891b2">📊 Piyasa</span>` : ""}${d.onem !== "NORMAL" ? `<span class="rozet" style="background:${onemRenk[d.onem]}">${d.onem === "ACIL" ? "🚨 Acil" : "⚠️ Önemli"}</span>` : ""}',
    "detail-badge")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
