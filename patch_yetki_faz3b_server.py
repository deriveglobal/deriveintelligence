# -*- coding: utf-8 -*-
# YETKI_FAZ3B (server) — Veri kapsamı sızıntı kapatma: _sahaScopeGuard + tekil müşteri GET + kart veri uçları
#   (finansal / olaylar / not). Kapsamlı kullanıcı ID bilse bile başkasının müşterisini AÇAMAZ/çekemez → 404.
#   OPT-IN: admin/tumu/kapsamsız → guard true (query yok, regresyon yok). Ön koşul: YETKI_FAZ3A (_sahaScopeSql).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ3B" in s:
    print("[skip] zaten yamalı"); sys.exit(0)
assert "_sahaScopeSql" in s, "önce YETKI_FAZ3A (_sahaScopeSql) olmalı"

# 1) _sahaScopeGuard — _sahaScopeSql'den ÖNCE (fonksiyon bildirimleri hoist; _sahaScopeSql'i çağırabilir)
SQL_FN = "  function _sahaScopeSql(sess, params, alias) {"
assert s.count(SQL_FN) == 1, "sahaScopeSql anchor=%d" % s.count(SQL_FN)
GUARD = '''  /* YETKI_FAZ3B — tek müşteri kapsam kontrolü (opt-in; admin/tumu -> true, sorgu yok). */
  async function _sahaScopeGuard(sess, musteriId) {
    if (!sess || sess.sahaRole === "admin") return true;
    const sc = (sess.permissions && sess.permissions.scope) || {};
    if (!sc.level || sc.level === "tumu") return true;
    const params = [sess.tenantId, musteriId];
    const r = await query("SELECT 1 FROM saha_musteri m WHERE m.tenant_id=$1 AND m.id=$2 AND m.aktif=true" + _sahaScopeSql(sess, params, "m"), params);
    return r.rowCount > 0;
  }
''' + SQL_FN
s = s.replace(SQL_FN, GUARD, 1)

# 2) 4 uca guard enjekte (match satırı + requireSahaAccess'ten sonra)
def inject(match_line, why):
    global s
    anchor = match_line + "\n      const session = await requireSahaAccess(request);"
    n = s.count(anchor); assert n == 1, "anchor '%s' count=%d" % (why, n)
    guard = '\n      if (!(await _sahaScopeGuard(session, m[1]))) { sendJson(response, 404, { error: "Müşteri bulunamadı." }); return; }  /* YETKI_FAZ3B */'
    s = s.replace(anchor, anchor + guard, 1)

inject('    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/musteriler/(${SAHA_UUID_RE})$`)))) {', "tekil-GET")
inject('    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/musteriler/(${SAHA_UUID_RE})/finansal$`)))) {', "finansal")
inject('    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/musteriler/(${SAHA_UUID_RE})/olaylar$`)))) {', "olaylar")
inject('    if (method === "POST" && (m = path.match(new RegExp(`^/api/saha/musteriler/(${SAHA_UUID_RE})/not$`)))) {', "not")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ3B (server) — _sahaScopeGuard + tekil GET/finansal/olaylar/not kapsam")
