# -*- coding: utf-8 -*-
# PORTFOYUM_SKOR_JOIN_V1 (v2) — /api/saha/portfoyum ucuna saha_satis_skor LEFT JOIN
#   Canlı (kompakt) endpoint biçimine göre anchor'lar. baseSql'e skor kolonları + LEFT JOIN
#   + JS map'te segment objesi. 1:1 (PK tenant+kod) → satır çoğaltmaz.
# Idempotent, .skorjoinbak yedekli. Fatih: python3 patch_portfoyum_skor_join.py <dizin>
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
REL  = "server_container.mjs"
MARK = "PORTFOYUM_SKOR_JOIN_V1"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit

# 1) SELECT'e skor kolonları (son12_gec_orani + FROM arası)
A_SEL = "AS son12_gec_orani\n        FROM saha_musteri m"
N_SEL = ("AS son12_gec_orani,\n"
         "          sk.segment AS skor_segment, sk.p_alive AS skor_palive, sk.exp30 AS skor_exp30, sk.siparis AS skor_siparis, sk.son_gun AS skor_son_gun, sk.medyan_gun AS skor_medyan  /* PORTFOYUM_SKOR_JOIN_V1 */\n"
         "        FROM saha_musteri m")
assert orig.count(A_SEL) == 1, "SELECT anchor=%d" % orig.count(A_SEL)

# 2) LEFT JOIN saha_satis_skor (bi_tahsilat join satirindan hemen sonra)
A_JOIN = "        LEFT JOIN bi_tahsilat      t ON t.tenant_id=m.tenant_id AND t.muhatap_kodu=m.musteri_kodu"
N_JOIN = (A_JOIN + "\n"
          "        LEFT JOIN saha_satis_skor  sk ON sk.tenant_id=m.tenant_id AND sk.musteri_kodu=m.musteri_kodu")
assert orig.count(A_JOIN) == 1, "JOIN anchor=%d" % orig.count(A_JOIN)

# 3) JS map: segment:null → segment objesi
A_SEG = "segment:null };"
N_SEG = ("segment: b.skor_segment ? { st:b.skor_segment, "
         "palive:b.skor_palive==null?null:Number(b.skor_palive), "
         "exp30:b.skor_exp30==null?null:Number(b.skor_exp30), "
         "siparis:b.skor_siparis, son_gun:b.skor_son_gun, medyan_gun:b.skor_medyan } : null };")
assert orig.count(A_SEG) == 1, "SEG anchor=%d" % orig.count(A_SEG)

s = orig.replace(A_SEL, N_SEL, 1).replace(A_JOIN, N_JOIN, 1).replace(A_SEG, N_SEG, 1)
if not os.path.exists(path + ".skorjoinbak"):
    with io.open(path + ".skorjoinbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
