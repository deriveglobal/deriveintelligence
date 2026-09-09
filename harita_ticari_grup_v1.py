#!/usr/bin/env python3
# HARITA_TICARI_GRUP_V1 — harita "Tüketici/Ticari ciro" ERP-geneli grup_adi'ye tasindi.
#   Sorun: il_tip CTE saha_musteri.tip JOIN'i kullaniyordu -> sadece ~293 roster musterisi sayiliyor,
#     gercek ticari ciro cok dusuk gorunuyordu (Fatih yakaladi). Cozum: bi_satis_faturalari.grup_adi
#     ('LASTIK TICARI'/'LASTIK TUKETICI') — TUM ERP satislari, kokpit /api/bi/ana ile ayni tanim.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_TICARI_GRUP_V1" in s:
    print("ticari-grup: already present, skip"); print("DONE."); raise SystemExit

A = '          + " il_tip AS (SELECT f.sehir il, SUM(f.satir_tutar) FILTER (WHERE sm.tip=\'TUKETICI\') ciro_tuketici, SUM(f.satir_tutar) FILTER (WHERE sm.tip=\'TICARI\') ciro_ticari FROM bi_satis_faturalari f JOIN saha_musteri sm ON sm.musteri_kodu=f.musteri_kodu AND sm.tenant_id::text=$1 WHERE f.tenant_id::text=$1 AND f.sehir IS NOT NULL AND f.sehir<>\'\' AND ($2::date IS NULL OR f.fatura_tarihi BETWEEN $2 AND $3) GROUP BY f.sehir)"\n'
assert s.count(A) == 1, "il_tip anchor (count=%d)" % s.count(A)

N = '          + " il_tip AS (SELECT sehir il, SUM(satir_tutar) FILTER (WHERE grup_adi=\'LASTIK TUKETICI\') ciro_tuketici, SUM(satir_tutar) FILTER (WHERE grup_adi=\'LASTIK TICARI\') ciro_ticari FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' AND ($2::date IS NULL OR fatura_tarihi BETWEEN $2 AND $3) GROUP BY sehir)" /* HARITA_TICARI_GRUP_V1 */\n'
s = s.replace(A, N, 1)
write(FP, s)
print("ticari-grup: il_tip saha_musteri.tip -> grup_adi (ERP-geneli, tam)")
print("marker:", s.count("HARITA_TICARI_GRUP_V1"))
print("DONE.")
