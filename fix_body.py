#!/usr/bin/env python3
# FIX_BODY_V1 — the restored saha endpoints (notlar, rep-brain, duyurular,
# konusmalar, oneri, hata) destructure `body` but never parse the request.
# Insert `const body = await readJson(request);` before each destructure.
# Atomic: builds in memory, asserts each anchor count, writes only at end.
import sys

fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
src = open(fn, encoding="utf-8").read()
orig = len(src)

def add_body(needle, n_expected=1):
    global src
    c = src.count(needle)
    assert c == n_expected, "ABORT: %r found %d (need %d)" % (needle.strip()[:55], c, n_expected)
    lead = needle[:len(needle) - len(needle.lstrip())]
    repl = lead + "const body = await readJson(request);\n" + needle
    src = src.replace(needle, repl)
    print("OK (x%d): %s" % (c, needle.strip()[:55]))

# notlar POST / PUT
add_body("      const { icerik, hatirlatma_tarihi } = body;")
add_body("      const { icerik, hatirlatma_tarihi, tamamlandi } = body;")
# rep-profil PUT
add_body("      const { base_adres, base_lat, base_lng } = body;")
# rep-brain (Asistan!)
add_body("      const { mesaj } = body;")
# duyurular POST
add_body("      const { baslik, icerik, onem='NORMAL' } = body;")
# konusmalar/coklu
add_body("      const { rep_ids, icerik } = body;")
# konusmalar/yayim + konusmalar/:id  (identical line, 2 occurrences)
add_body("      const { icerik } = body;", n_expected=2)
# oneri POST
add_body("      const { kategori='GENEL', baslik, mesaj } = body;")
# oneriler PUT
add_body("      const { durum, yonetici_notu } = body;")
# log-hata (inside try, 8-space indent, no auth)
add_body("        const { tip, view_adi, endpoint, http_status, hata_mesaji, duration_ms, extra } = body;")
# hata-raporu
add_body("      const { tip='manual', view_adi, endpoint, hata_mesaji, extra } = body;")

open(fn, "w", encoding="utf-8").write(src)
print("WROTE %s  (%d -> %d chars, +%d)" % (fn, orig, len(src), len(src) - orig))
