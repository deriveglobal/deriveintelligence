# -*- coding: utf-8 -*-
# KANAL_LABEL_V1 (mobil) — Mesajlar broadcast'i "Hızlı Duyuru" olarak netlestir (Duyurular=resmi).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "KANAL_LABEL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) buton
OLD1 = '<button class="saha-cta" id="yayim-btn">📣 Toplu Mesaj Gönder</button>'
NEW1 = '<button class="saha-cta" id="yayim-btn">📣 Hızlı Duyuru Gönder</button><!--KANAL_LABEL_V1-->'
assert s.count(OLD1) == 1, "btn anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# E2) baslik
OLD2 = '<div style="font-size:11px;font-weight:700;color:#854d0e;margin-bottom:6px">SON YAYIMLAR</div>'
NEW2 = '<div style="font-size:11px;font-weight:700;color:#854d0e;margin-bottom:6px">SON HIZLI DUYURULAR</div>'
assert s.count(OLD2) == 1, "baslik anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# E3) modal basligi + ipucu
OLD3 = """  modal(`
    <h3>📣 Toplu Mesaj Gönder</h3>
    <label class="etiket" style="margin-bottom:6px">Alıcılar</label>"""
NEW3 = """  modal(`
    <h3>📣 Hızlı Duyuru Gönder</h3>
    <div style="font-size:11px;color:#94a3b8;margin:-4px 0 8px">Kısa/anlık bilgi için. Resmi & kalıcı duyuru → <b>Duyurular</b> sekmesi.</div>
    <label class="etiket" style="margin-bottom:6px">Alıcılar</label>"""
assert s.count(OLD3) == 1, "modal anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KANAL_LABEL_V1 (mobil)")
