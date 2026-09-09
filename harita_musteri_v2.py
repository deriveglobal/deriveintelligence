#!/usr/bin/env python3
# HARITA_MUSTERI_V2 — /api/saha/harita-musteriler: koordinat kaynagini genislet.
#   saha_musteri.lat/lng YOKSA, o musterinin EN SON ziyaret check-in konumunu (saha_ziyaret.checkin_lat/lng) kullan.
#   Boylece uygulamadan GPS'le kaydedilenlere ek olarak, sahada check-in yapilan tum musteriler haritada belirir.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_MUSTERI_V2" in s:
    print("harita-musteri-v2: already present, skip"); print("DONE."); raise SystemExit

A = (
    '      const hr = await query(\n'
    '        "SELECT m.id, m.firma, m.tip, m.durum, m.il, m.ilce, m.lat, m.lng, COALESCE(u.full_name, u.email) AS rep"\n'
    '        + " FROM saha_musteri m LEFT JOIN users u ON u.id = m.sorumlu_rep"\n'
    '        + " WHERE m.tenant_id = $1 AND m.aktif = true AND m.lat IS NOT NULL AND m.lng IS NOT NULL" + tipW\n'
    '        + " ORDER BY m.firma LIMIT 5000", hb);\n'
)
assert s.count(A) == 1, "V1 query anchor (count!=1)"

N = (
    '      const hr = await query( /* HARITA_MUSTERI_V2 */\n'
    '        "SELECT m.id, m.firma, m.tip, m.durum, m.il, m.ilce,"\n'
    '        + " COALESCE(m.lat, ci.lat) AS lat, COALESCE(m.lng, ci.lng) AS lng,"\n'
    '        + " (m.lat IS NULL) AS ziyaret_konum, COALESCE(u.full_name, u.email) AS rep"\n'
    '        + " FROM saha_musteri m"\n'
    '        + " LEFT JOIN LATERAL (SELECT z.checkin_lat AS lat, z.checkin_lng AS lng FROM saha_ziyaret z WHERE z.tenant_id = m.tenant_id AND z.musteri_id = m.id AND z.checkin_lat IS NOT NULL ORDER BY z.checkin_at DESC NULLS LAST LIMIT 1) ci ON true"\n'
    '        + " LEFT JOIN users u ON u.id = m.sorumlu_rep"\n'
    '        + " WHERE m.tenant_id = $1 AND m.aktif = true AND COALESCE(m.lat, ci.lat) IS NOT NULL" + tipW\n'
    '        + " ORDER BY m.firma LIMIT 5000", hb);\n'
)
s = s.replace(A, N, 1)
write(FP, s)
print("harita-musteri-v2: check-in konum fallback eklendi")
print("marker count:", s.count("HARITA_MUSTERI_V2"))
print("DONE.")
