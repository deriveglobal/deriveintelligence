# -*- coding: utf-8 -*-
# KANAL_LABEL_DK_V1 (masaustu) — Mesajlar broadcast'i "Hızlı Duyuru" olarak netlestir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "KANAL_LABEL_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) buton
OLD1 = '<button class="dk-btn" id="msg-yayim">📣 Toplu Mesaj</button>'
NEW1 = '<button class="dk-btn" id="msg-yayim">📣 Hızlı Duyuru</button><!--KANAL_LABEL_DK_V1-->'
assert s.count(OLD1) == 1, "btn anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# E2) baslik
OLD2 = '<div class="dk-det-yh" style="color:var(--sari)">Son Yayımlar</div>'
NEW2 = '<div class="dk-det-yh" style="color:var(--sari)">Son Hızlı Duyurular</div>'
assert s.count(OLD2) == 1, "baslik anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# E3) modal basligi + ipucu (yayimMesaj)
OLD3 = '  dkModal(`<div class="dk-det-head"><h3>📣 Toplu Mesaj Gönder</h3><button class="dk-x" data-kapat>✕</button></div>'
NEW3 = '  dkModal(`<div class="dk-det-head"><h3>📣 Hızlı Duyuru Gönder</h3><button class="dk-x" data-kapat>✕</button></div>\n    <div class="sub2" style="margin:2px 0 8px">Kısa/anlık bilgi için. Resmi & kalıcı duyuru → <b>Duyurular</b> sekmesi.</div>'
assert s.count(OLD3) == 1, "modal anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KANAL_LABEL_DK_V1 (masaustu)")
