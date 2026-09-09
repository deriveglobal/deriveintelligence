import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "PUSH_INBOX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert s.count(old) == 1, "anchor %s count=%d" % (tag, s.count(old))
    s = s.replace(old, new, 1); print("[ok]", tag)

HELPERS = '''/* PUSH_INBOX_V1 — bildirim deposu (inbox) + yönetici id yardımcıları */
let _bildirimReady = false;
async function ensureBildirim() {
  if (_bildirimReady) return;
  await pool.query("CREATE TABLE IF NOT EXISTS bi_bildirim (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, user_id uuid NOT NULL, baslik text, govde text, tip text, data jsonb NOT NULL DEFAULT '{}'::jsonb, okundu boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now())");
  await pool.query("CREATE INDEX IF NOT EXISTS idx_bi_bildirim_user ON bi_bildirim (tenant_id, user_id, created_at DESC)");
  _bildirimReady = true;
}
async function _storeBildirim(tenantId, userIds, title, body, data) {
  try {
    const ids = (Array.isArray(userIds) ? userIds : [userIds]).filter(Boolean);
    if (!ids.length) return;
    await ensureBildirim();
    await pool.query("INSERT INTO bi_bildirim (tenant_id,user_id,baslik,govde,tip,data) SELECT $1, uid, $3, $4, $5, $6 FROM unnest($2::uuid[]) AS uid", [tenantId, ids, title, body, (data && data.type) || null, JSON.stringify(data || {})]);
  } catch (e) { try { console.warn("storeBildirim:", e.message); } catch (er) {} }
}
async function sahaManagerIds(tenantId, exceptUserId) {
  try {
    const r = await pool.query("SELECT DISTINCT u.id FROM users u JOIN tenant_user_modules tum ON tum.user_id=u.id AND tum.module_id='saha' AND tum.tenant_id=$1 AND tum.active=true LEFT JOIN tenant_users tu ON tu.user_id=u.id AND tu.tenant_id=$1 AND tu.active=true WHERE u.status <> 'disabled' AND (tum.module_role IN ('admin','manager') OR tu.tenant_role='company_owner')", [tenantId]);
    return r.rows.map(function (x) { return x.id; }).filter(function (id) { return id && id !== exceptUserId; });
  } catch (e) { try { console.warn("sahaManagerIds:", e.message); } catch (er) {} return []; }
}
'''

# A) helper bloğu + pushToTenant içine inbox-store (duyuru da inbox'a düşsün)
rep(
'''async function pushToTenant(tenantId, exceptUserId, title, body, data) {
  try {
    const r = await pool.query("SELECT token, platform FROM bi_push_token WHERE tenant_id=$1 AND user_id <> $2", [tenantId, exceptUserId || "00000000-0000-0000-0000-000000000000"]);''',
HELPERS +
'''async function pushToTenant(tenantId, exceptUserId, title, body, data) {
  try {
    try { const _ur = await pool.query("SELECT DISTINCT u.id FROM users u JOIN tenant_user_modules tum ON tum.user_id=u.id AND tum.module_id='saha' AND tum.tenant_id=$1 AND tum.active=true WHERE u.status <> 'disabled' AND u.id <> $2", [tenantId, exceptUserId || "00000000-0000-0000-0000-000000000000"]); await _storeBildirim(tenantId, _ur.rows.map(function (x) { return x.id; }), title, body, data); } catch (e) {}
    const r = await pool.query("SELECT token, platform FROM bi_push_token WHERE tenant_id=$1 AND user_id <> $2", [tenantId, exceptUserId || "00000000-0000-0000-0000-000000000000"]);''',
"helpers+tenant-store")

# B) pushToUsers içine inbox-store (token olmasa da inbox'a düşsün)
rep(
'''    const ids = (Array.isArray(userIds) ? userIds : [userIds]).filter(Boolean);
    if (!ids.length) return { ok: 0, fail: 0, total: 0 };
    const r = await pool.query("SELECT token, platform FROM bi_push_token WHERE tenant_id=$1 AND user_id = ANY($2::uuid[])", [tenantId, ids]);''',
'''    const ids = (Array.isArray(userIds) ? userIds : [userIds]).filter(Boolean);
    if (!ids.length) return { ok: 0, fail: 0, total: 0 };
    try { await _storeBildirim(tenantId, ids, title, body, data); } catch (e) {}
    const r = await pool.query("SELECT token, platform FROM bi_push_token WHERE tenant_id=$1 AND user_id = ANY($2::uuid[])", [tenantId, ids]);''',
"users-store")

# C) VISIT create hook — yöneticilere anlık (giren hariç)
rep(
'      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan });',
'''      try { sahaManagerIds(session.tenantId, session.userId).then(function (ids) { if (!ids.length) return; pool.query("SELECT firma FROM saha_musteri WHERE id=$1", [result.rows[0].musteri_id]).then(function (mr) { pushToUsers(session.tenantId, ids, "🚪 Yeni ziyaret", ((mr.rows[0] && mr.rows[0].firma) || "Müşteri") + " ziyaret edildi", { room: "saha", type: "ziyaret", id: result.rows[0].id }); }).catch(function () {}); }).catch(function () {}); } catch (e) {} /* PUSH_HOOKS_V3 */
      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan });''',
"visit-hook")

# D) QUOTE create hook — yöneticilere anlık (giren hariç)
rep(
'      const teklifId = hdr.rows[0].id;',
'''      const teklifId = hdr.rows[0].id;
      try { sahaManagerIds(session.tenantId, session.userId).then(function (ids) { if (!ids.length) return; pool.query("SELECT firma FROM saha_musteri WHERE id=$1", [p.musteri_id]).then(function (mr) { var fn = (mr.rows[0] && mr.rows[0].firma) || "Müşteri"; pushToUsers(session.tenantId, ids, "🧾 Yeni teklif", fn + (ilk.marka ? " — " + ilk.marka : "") + (toplamTutar ? " · ₺" + Math.round(toplamTutar).toLocaleString("tr-TR") : ""), { room: "saha", type: "teklif_yeni", id: teklifId }); }).catch(function () {}); }).catch(function () {}); } catch (e) {} /* PUSH_HOOKS_V3 */''',
"quote-hook")

# E) inbox endpoints (reps endpoint'inden sonra)
rep(
'''      sendJson(response, 200, { reps: rows.rows });
      return;
    }''',
'''      sendJson(response, 200, { reps: rows.rows });
      return;
    }

    // ── Bildirim kutusu (inbox) — PUSH_INBOX_V1 ──
    if (method === "GET" && path === "/api/saha/bildirimler") {
      const session = await requireSahaAccess(request);
      await ensureBildirim();
      const rows = await pool.query("SELECT id, baslik, govde, tip, data, okundu, created_at FROM bi_bildirim WHERE tenant_id=$1 AND user_id=$2 ORDER BY created_at DESC LIMIT 100", [session.tenantId, session.userId]);
      const okunmamis = rows.rows.filter(function (x) { return !x.okundu; }).length;
      sendJson(response, 200, { bildirimler: rows.rows, okunmamis: okunmamis });
      return;
    }
    if (method === "POST" && path === "/api/saha/bildirimler/okundu") {
      const session = await requireSahaAccess(request);
      await ensureBildirim();
      const b = await readJson(request).catch(function () { return {}; });
      if (b && b.id) await pool.query("UPDATE bi_bildirim SET okundu=true WHERE tenant_id=$1 AND user_id=$2 AND id=$3", [session.tenantId, session.userId, b.id]);
      else await pool.query("UPDATE bi_bildirim SET okundu=true WHERE tenant_id=$1 AND user_id=$2 AND okundu=false", [session.tenantId, session.userId]);
      sendJson(response, 200, { ok: true });
      return;
    }''',
"inbox-endpoints")

open(F, "w", encoding="utf-8").write(s)
print("[done] PUSH_INBOX_V1 + PUSH_HOOKS_V3")
