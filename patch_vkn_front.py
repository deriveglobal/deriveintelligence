# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# VKN_EDIT_FRONT — make the VKN row on the customer card editable for non-ERP
# customers (prospects / free entries), so a rep can drop the tax number in
# later. ERP-linked customers keep the read-only VKN (it comes from SAP).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) VKN row: read-only when ERP-linked, editable input+save when a prospect
rep(
    '''    ${m.kimlik_vergi_no ? `<div class="det-satir"><span>VKN</span><b>${esc(m.kimlik_vergi_no)}</b></div>` : ""}''',
    '''    ${m.musteri_kodu
      ? (m.kimlik_vergi_no ? `<div class="det-satir"><span>VKN</span><b>${esc(m.kimlik_vergi_no)}</b></div>` : "")
      : `<div class="det-satir"><span>VKN</span>
          <span style="display:flex;align-items:center;gap:6px">
            <input class="giris" id="md-vkn" inputmode="numeric" placeholder="10 hane — sonradan eklenebilir" value="${esc(m.vergi_no || "")}" style="font-size:13px;padding:4px 8px;display:inline-block;width:auto;margin-bottom:0">
            <button class="btn kucuk" id="md-vkn-kaydet">Kaydet</button>
          </span></div>`}''',
    "vkn-row")

# 2) VKN save handler (inserted before the visit-history block)
rep(
    '''  // Ziyaret geçmişi: tarih + temsilci + not (tıklayınca tam detay)''',
    '''  document.getElementById("md-vkn-kaydet")?.addEventListener("click", async () => {
    const v = (document.getElementById("md-vkn")?.value || "").replace(/\\D/g, "");
    if (v && (v.length < 10 || v.length > 11)) { uyari("Vergi No 10, TC 11 hane olmalı."); return; }
    try {
      await api(`/api/saha/musteriler/${m.id}`, { method: "PUT", body: JSON.stringify({ vergi_no: v || null }) });
      uyari(v ? "✓ Vergi No kaydedildi." : "✓ Vergi No temizlendi.", true);
      m.vergi_no = v || null; m.kimlik_vergi_no = v || null;
      if (S.musteriler) { const idx = S.musteriler.findIndex(x => x.id === m.id); if (idx !== -1) S.musteriler[idx].vergi_no = v || null; }
    } catch (e) { uyari(e.message); }
  });
  // Ziyaret geçmişi: tarih + temsilci + not (tıklayınca tam detay)''',
    "vkn-handler")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
