#!/usr/bin/env python3
# HARITA (Faz 1) server: HARITA_CSP_V1 (CSP'ye Leaflet CDN + OSM tile ekle)
#                        + HARITA_MUSTERI_V1 (GET /api/saha/harita-musteriler).
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
changed = 0

# (1) CSP gevset — Leaflet (cdnjs) + OSM tile
if "HARITA_CSP_V1" not in s:
    A_csp = '  "Content-Security-Policy": "default-src \'self\'; script-src \'self\' \'unsafe-inline\'; style-src \'self\' \'unsafe-inline\'; img-src \'self\' data: blob:; connect-src \'self\'; font-src \'self\' data:"\n'
    assert s.count(A_csp) == 1, "CSP anchor (count!=1)"
    N_csp = '  "Content-Security-Policy": "default-src \'self\'; script-src \'self\' \'unsafe-inline\' https://cdnjs.cloudflare.com; style-src \'self\' \'unsafe-inline\' https://cdnjs.cloudflare.com; img-src \'self\' data: blob: https://tile.openstreetmap.org https://*.tile.openstreetmap.org; connect-src \'self\'; font-src \'self\' data:" /* HARITA_CSP_V1 */\n'
    s = s.replace(A_csp, N_csp, 1)
    changed += 1
    print("csp: eklendi")
else:
    print("csp: zaten var")

# (2) Yeni uc — koordinatli musteriler
if "HARITA_MUSTERI_V1" not in s:
    A_ep = '    if (method === "GET" && path === "/api/saha/harita") {\n'
    assert s.count(A_ep) == 1, "harita endpoint anchor (count!=1)"
    N_ep = (
        '    if (method === "GET" && path === "/api/saha/harita-musteriler") { /* HARITA_MUSTERI_V1 */\n'
        '      const session = await requireSahaAccess(request, ["rep","manager","admin"]);\n'
        '      const hsp = new URL(request.url, "http://x").searchParams;\n'
        '      const hTip = hsp.get("tip") || "";\n'
        '      const hb = [session.tenantId];\n'
        '      let tipW = "";\n'
        '      if (hTip === "TUKETICI" || hTip === "TICARI") { hb.push(hTip); tipW = " AND m.tip = $" + hb.length; }\n'
        '      const hr = await query(\n'
        '        "SELECT m.id, m.firma, m.tip, m.durum, m.il, m.ilce, m.lat, m.lng, COALESCE(u.full_name, u.email) AS rep"\n'
        '        + " FROM saha_musteri m LEFT JOIN users u ON u.id = m.sorumlu_rep"\n'
        '        + " WHERE m.tenant_id = $1 AND m.aktif = true AND m.lat IS NOT NULL AND m.lng IS NOT NULL" + tipW\n'
        '        + " ORDER BY m.firma LIMIT 5000", hb);\n'
        '      sendJson(response, 200, { musteriler: hr.rows });\n'
        '      return;\n'
        '    }\n\n'
    )
    s = s.replace(A_ep, N_ep + A_ep, 1)
    changed += 1
    print("endpoint: eklendi")
else:
    print("endpoint: zaten var")

if changed:
    write(FP, s)
print("marker CSP:", s.count("HARITA_CSP_V1"), "| MUSTERI:", s.count("HARITA_MUSTERI_V1"))
print("DONE.")
