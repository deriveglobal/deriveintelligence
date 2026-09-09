#!/usr/bin/env python3
# NOT_TAMAMLA_BTN_V1 (client) — Notlarim sekmesinde hatirlatma/not kartlarinda gorunur "✓ Tamamla"
#   butonu yoktu; tek "tamamla" kontrolu soldaki BOS kucuk daireydi (madde imi gibi gorunuyor, kimse
#   buton oldugunu anlamiyor). Ali Kemal Picakci ekran goruntusu ile teyit. Plan sekmesinde acik
#   "✓ Tamamla" butonu var; Notlarim'da yoktu → karisiklik.
#   Fix: notKart footer'ina acik yesil "✓ Tamamla" (acik) / "✓ Tamamlandi" (kapali) ekle;
#   mevcut data-toggle-done handler'ina baglanir (ekstra sunucu degisikligi yok).
#   Idempotent (marker: NOT_TAMAMLA_BTN_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "NOT_TAMAMLA_BTN_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old_alt = '''      <div class="kart-alt" style="margin-top:5px">
        <span style="color:#94a3b8">${tarih}</span>
        ${n.musteri ? `<span style="color:#0f766e;font-weight:600">🏢 ${esc(n.musteri)}</span>` : ""}
        ${hatirlatmaStr ? `<span style="color:${hatirlatmaRenk};font-weight:600">⏰ ${hatirlatmaStr}${hatirlatmaGecti ? " · gecikti" : hatirlatmaBugun ? " · bugün" : ""}</span>` : ""}
      </div>'''
new_alt = '''      <div class="kart-alt" style="margin-top:5px;display:flex;flex-wrap:wrap;align-items:center;gap:6px 10px">
        <span style="color:#94a3b8">${tarih}</span>
        ${n.musteri ? `<span style="color:#0f766e;font-weight:600">🏢 ${esc(n.musteri)}</span>` : ""}
        ${hatirlatmaStr ? `<span style="color:${hatirlatmaRenk};font-weight:600">⏰ ${hatirlatmaStr}${hatirlatmaGecti ? " · gecikti" : hatirlatmaBugun ? " · bugün" : ""}</span>` : ""}
        ${n.tamamlandi
          ? `<span style="margin-left:auto;color:#10b981;font-weight:700;font-size:12px">✓ Tamamlandı</span>`
          : `<button data-toggle-done type="button" style="margin-left:auto;background:#dcfce7;color:#16a34a;border:1px solid #86efac;border-radius:8px;padding:6px 14px;font-size:13px;font-weight:700;cursor:pointer">✓ Tamamla</button>`}
      </div>'''  # NOT_TAMAMLA_BTN_V1
if old_alt not in src:
    print("HATA: notKart kart-alt anchor bulunamadi"); sys.exit(1)
# Ekstra yorum python tarafinda; JS'e marker'i ayrica koyalim ki grep bulsun
new_alt_js = new_alt.replace("</div>'''  # NOT_TAMAMLA_BTN_V1", "</div>")
src = src.replace(old_alt, '''      <!-- ''' + MARK + ''' -->\n''' + new_alt_js, 1)
print("[+] Notlarim: acik '✓ Tamamla' butonu eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
