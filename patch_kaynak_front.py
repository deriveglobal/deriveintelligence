# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# KAYNAK_FRONT — quote source: required Kaynak selector on direct quotes
# (hidden when created from a visit -> auto Ziyaret) + source badge on cards.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) source label map
rep("const TEKLIF_DURUM = {",
    'const KAYNAK_ETK = { ZIYARET: "🚶 Ziyaret", TELEFON: "📞 Telefon", WHATSAPP: "💬 WhatsApp", EMAIL: "✉️ E-posta", DIGER: "Diğer" };\nconst TEKLIF_DURUM = {',
    "kaynak-map")

# 2) required Kaynak selector on the direct quote form (auto when from a visit)
rep('    <label>Genel Not<textarea class="giris" id="tf-genel-not" rows="2" placeholder="Teklif geneli için not…"></textarea></label>',
    '    <label>Genel Not<textarea class="giris" id="tf-genel-not" rows="2" placeholder="Teklif geneli için not…"></textarea></label>\n    ${ziyaretId ? "" : `<label>Kaynak *<select class="giris" id="tf-kaynak"><option value="">— Nereden geldi? —</option><option value="TELEFON">📞 Telefon</option><option value="WHATSAPP">💬 WhatsApp</option><option value="EMAIL">✉️ E-posta</option><option value="DIGER">Diğer</option></select></label>`}',
    "form-selector")

# 3) payload + required validation
rep('''    const genelNot = document.getElementById("tf-genel-not").value.trim() || null;
    try {
      await api("/api/saha/teklifler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id,
          ziyaret_id: ziyaretId,
          notlar    : genelNot,
          kalemler  : allKalemler
        })
      });''',
    '''    const genelNot = document.getElementById("tf-genel-not").value.trim() || null;
    const kaynak = ziyaretId ? "ZIYARET" : (document.getElementById("tf-kaynak")?.value || "");
    if (!ziyaretId && !kaynak) { uyari("Teklif kaynağını seçin (Telefon/WhatsApp/E-posta)."); return; }
    try {
      await api("/api/saha/teklifler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id,
          ziyaret_id: ziyaretId,
          kaynak    : kaynak,
          notlar    : genelNot,
          kalemler  : allKalemler
        })
      });''',
    "payload")

# 4) source badge on the quote card
rep('''      ${yonetici ? `<span>👤 ${esc(t.rep_full_name || "")}</span>` : ""}
      <span>${new Date(t.created_at).toLocaleDateString("tr-TR")}</span>''',
    '''      ${yonetici ? `<span>👤 ${esc(t.rep_full_name || "")}</span>` : ""}
      <span>${new Date(t.created_at).toLocaleDateString("tr-TR")}</span>
      ${t.kaynak ? `<span>${KAYNAK_ETK[t.kaynak] || t.kaynak}</span>` : ""}''',
    "card-badge", 2)

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
