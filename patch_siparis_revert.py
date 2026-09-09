#!/usr/bin/env python3
# FINANS_SIPARIS_REVERT_V1 — Sipariş bekleyen kartini "—"e geri cek: bi_stok_durumu.siparis_miktar
# kolonunun ERP anlami + populasyon kaynagi dogrulanamadi (erp_ingest.py'de mapping YOK). Anlami belirsiz metrik gosterme.
# Diger 3 metrik (olu stok/olculen tahsilat/sizinti) dogrulanmis, kalir. id kaldirilinca .then fill no-op olur.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
old = '<span class="badge live">canlı</span></div>\n           <div class="v num" id="gSiparis">— <small>M ₺</small></div><div class="plain">Yolda olan / bekleyen sipariş değeri — gelen sermaye.</div>'
new = '<span class="badge prov">doğrulanıyor</span></div>\n           <div class="v num">— <small>/* FINANS_SIPARIS_REVERT_V1 */</small></div><div class="plain">Sipariş bekleyen — kaynak (bi_stok_durumu.siparis_miktar) ERP anlamı doğrulanana kadar bağlanmadı.</div>'
if new in src: print("SKIP (zaten revert)")
else:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c})"
    bak = PATH + ".bak_siparisrevert_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    src = src.replace(old, new)
    with open(PATH, "w", encoding="utf-8") as f: f.write(src)
    print("OK: Sipariş bekleyen -> placeholder (doğrulanıyor)")
print("FINANS_SIPARIS_REVERT_V1 marker:", src.count("FINANS_SIPARIS_REVERT_V1"))
