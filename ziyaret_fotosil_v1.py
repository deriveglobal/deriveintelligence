#!/usr/bin/env python3
# ZIYARET_FOTO_SIL_V1 — tekil ziyaret fotografini silen DELETE ucu.
#   DELETE /api/saha/ziyaretler/:zid/foto/:fid — sahip (rep) veya manager/admin.
#   Ziyaret duzenlemede foto silme icin gerekli (bulk-delete zaten sadece ziyaret silmede vardi).
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "ZIYARET_FOTO_SIL_V1" in s:
    print("fotosil: already present, skip"); print("DONE."); raise SystemExit

A = "    // ── Ziyaretin foto listesi ──\n"
assert s.count(A) == 1, "foto listesi anchor (count!=1)"

N = (
    "    // ── Tekil foto sil (duzenleme) — ZIYARET_FOTO_SIL_V1 ──\n"
    "    if (method === \"DELETE\" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/foto/(${SAHA_UUID_RE})$`)))) {\n"
    "      const session = await requireSahaAccess(request);\n"
    "      const own = await query(`SELECT rep_id FROM saha_ziyaret WHERE tenant_id = $1 AND id = $2`, [session.tenantId, m[1]]);\n"
    "      if (!own.rowCount) { sendJson(response, 404, { error: \"Ziyaret bulunamadı.\" }); return; }\n"
    "      if (session.sahaRole === \"rep\" && own.rows[0].rep_id !== session.userId) {\n"
    "        sendJson(response, 403, { error: \"Sadece kendi ziyaretinizin fotoğrafını silebilirsiniz.\" }); return;\n"
    "      }\n"
    "      const del = await query(`DELETE FROM saha_ziyaret_foto WHERE tenant_id = $1 AND ziyaret_id = $2 AND id = $3 RETURNING id`, [session.tenantId, m[1], m[2]]);\n"
    "      if (!del.rowCount) { sendJson(response, 404, { error: \"Fotoğraf bulunamadı.\" }); return; }\n"
    "      sendJson(response, 200, { ok: true, silinen: m[2] });\n"
    "      return;\n"
    "    }\n\n"
)

s = s.replace(A, N + A, 1)
write(FP, s)
print("fotosil: DELETE /api/saha/ziyaretler/:zid/foto/:fid eklendi")
print("marker count:", s.count("ZIYARET_FOTO_SIL_V1"))
print("DONE.")
