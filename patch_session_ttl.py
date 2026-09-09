import sys, io
path = sys.argv[1]
with io.open(path, encoding="utf-8") as f: src = f.read()
if "SESSION_TTL_V1" in src:
    print("[patch_session_ttl] zaten uygulanmis, atlaniyor."); sys.exit(0)

edits = []

# D) helper + sabitler (createSession tanimindan ONCE)
HELPER = '''// SESSION_TTL_V1 — rol-bazli oturum omru (guvenlik): yonetici/mudur 24s, saha temsilcisi 7g.
//   Client AUTO_LOGOUT_V1 politikasini SUNUCUDA da uygular; calinan cerez 14 gun yasamaz.
//   Her cagri try/catch ile korunur: hata olursa rep TTL'e duser, giris ASLA kirilmaz.
const SESSION_TTL_STAFF_MS = 24 * 60 * 60 * 1000;
const SESSION_TTL_REP_MS   = 7 * 24 * 60 * 60 * 1000;
async function _sessionTtlMs(userId, platformRole) {
  const pr = String(platformRole || "").toLowerCase();
  if (pr === "platform_owner" || pr === "company_owner" || pr === "admin") return SESSION_TTL_STAFF_MS;
  try {
    const r = await query(
      `SELECT 1 FROM tenant_user_modules
        WHERE user_id = $1 AND active = true AND module_role IN ('admin','manager') LIMIT 1`,
      [userId]);
    return r.rowCount ? SESSION_TTL_STAFF_MS : SESSION_TTL_REP_MS;
  } catch (e) { return SESSION_TTL_REP_MS; }
}
'''
edits.append((
  'async function createSession(userId, metadata = {}, expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14)) {',
  HELPER + 'async function createSession(userId, metadata = {}, expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14)) {'
))

# A) authenticateUser: erken expiresAt -> let (fallback korunur)
edits.append((
  '  const normalized = normalizeEmail(email);\n  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14);',
  '  const normalized = normalizeEmail(email);\n  let expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14); // SESSION_TTL_V1 fallback'
))

# B) authenticateUser: createSession oncesi rol-bazli hesapla
edits.append((
  '  const token = await createSession(user.id, { userAgent: "password" }, expiresAt);',
  '  try { expiresAt = new Date(Date.now() + await _sessionTtlMs(user.id, user.role)); } catch (e) {} // SESSION_TTL_V1\n  const token = await createSession(user.id, { userAgent: "password" }, expiresAt);'
))

# C) 2FA yolu: ayni sekilde
edits.append((
  '      const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14);\n      const token = await createSession(pending.userId, { userAgent: "password+2fa" }, expiresAt);',
  '      let expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14);\n      try { expiresAt = new Date(Date.now() + await _sessionTtlMs(pending.userId, null)); } catch (e) {} // SESSION_TTL_V1\n      const token = await createSession(pending.userId, { userAgent: "password+2fa" }, expiresAt);'
))

for i,(old,new) in enumerate(edits):
    c = src.count(old)
    if c != 1:
        sys.stderr.write("[patch_session_ttl] HATA: edit %d anchor %d kez bulundu (1 bekleniyordu).\n" % (i, c)); sys.exit(2)
    src = src.replace(old, new, 1)

with io.open(path, "w", encoding="utf-8") as f: f.write(src)
print("[patch_session_ttl] uygulandi (4 edit).")
