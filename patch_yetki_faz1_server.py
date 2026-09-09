# -*- coding: utf-8 -*-
# YETKI_FAZ1 (server) — kart uclarini musterikart capability'ye bagla (matris-tabanli, hardcode/bypass DEGIL).
#   (a) _sahaCap(sess,cap) yardimcisi: admin bypass · bos departments -> rol fallback · includes (client _yetki ile birebir).
#   (b) /api/bi merkezi 'sales' kapisindan 4 kart ucunu muaf tut (kendi handler'i musterikart enforce eder).
#   (c) 6 kart ucunun manager/admin kapisini _sahaCap(...,"musterikart") ile degistir.
#   On kosul: YETKI_FAZ0 (server base) uygulanmis.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

def swap_after(marker, old, new, why):
    global s
    i = s.find(marker); assert i != -1, "marker yok: %s" % why
    j = s.find(old, i);  assert j != -1, "old yok: %s" % why
    s = s[:j] + new + s[j+len(old):]

def rep(old, new, why):
    global s
    n = s.count(old); assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# (a) _sahaCap yardimcisi — requireSahaDept'ten once (ayni scope)
HELPER_ANCHOR = "  async function requireSahaDept(request, dept) {"
assert s.count(HELPER_ANCHOR) == 1, "requireSahaDept anchor=%d" % s.count(HELPER_ANCHOR)
HELPER = ('  /* YETKI_FAZ1 — capability kontrolu (client _yetki / _enforceSahaDept ile birebir): '
          'admin bypass; bos departments -> rol fallback (izin); degilse includes. */\n'
          '  function _sahaCap(sess, cap) { if (!sess) return false; if (sess.sahaRole === "admin") return true; '
          'const d = Array.isArray(sess.permissions && sess.permissions.departments) ? sess.permissions.departments : []; '
          'return (!d.length) ? true : d.includes(cap); }\n\n')
s = s.replace(HELPER_ANCHOR, HELPER + HELPER_ANCHOR, 1)

# (b) merkezi /api/bi 'sales' kapisindan 4 kart ucunu muaf tut
OLD_GATE = """    try {
      await requireBiDept(request, _dept);
    } catch (e) {
      sendJson(response, e.statusCode || 403,
               { error: e.message || 'Yetkiniz yok.', gereken_yetki: _dept });
      return;
    }
  }"""
NEW_GATE = """    /* YETKI_FAZ1 — musteri karti uclari merkezi 'sales' kapisindan muaf; kendi handler'i musterikart enforce eder. */
    if (!(_p === '/api/bi/musteri-skor' || _p === '/api/bi/musteri-kiyas' || _p === '/api/bi/musteri-fiyat-liste' || _p === '/api/bi/ebat-ara')) {
    try {
      await requireBiDept(request, _dept);
    } catch (e) {
      sendJson(response, e.statusCode || 403,
               { error: e.message || 'Yetkiniz yok.', gereken_yetki: _dept });
      return;
    }
    }
  }"""
rep(OLD_GATE, NEW_GATE, "merkezi-kapi-muafiyet")

# (c) 6 kart ucu: manager/admin -> musterikart capability
GUARD_OLD = 'if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }'
GUARD_NEW = 'if (!_s && !(_ss && _sahaCap(_ss, "musterikart"))) { sendJson(response, 403, { error: "yetki yok" }); return; }  /* YETKI_FAZ1 */'
for pth in ("/api/bi/musteri-skor", "/api/bi/musteri-fiyat-liste", "/api/bi/musteri-kiyas"):
    swap_after('url.pathname === "%s"' % pth, GUARD_OLD, GUARD_NEW, "guard:" + pth)

swap_after('url.pathname === "/api/bi/ebat-ara"',
           'let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));',
           'let ok = s ? true : (ss && _sahaCap(ss, "musterikart"));  /* YETKI_FAZ1 */', "ebat-ara")

# AI ozet: rolsuz requireSahaAccess + musterikart cap check
swap_after('/api/saha/ai/musteri-ozeti/',
           'const session = await requireSahaAccess(request, ["manager", "admin"]);',
           'const session = await requireSahaAccess(request);\n      if (!_sahaCap(session, "musterikart")) { sendJson(response, 403, { error: "yetki yok" }); return; }  /* YETKI_FAZ1 */',
           "ai-ozet")

# mesaj: rolsuz requireSahaAccess + musterikart cap check (bosluksuz varyant)
swap_after('([^/]+)\\/mesaj$/',
           'const session = await requireSahaAccess(request, ["manager","admin"]);',
           'const session = await requireSahaAccess(request);\n      if (!_sahaCap(session, "musterikart")) { sendJson(response, 403, { error: "yetki yok" }); return; }  /* YETKI_FAZ1 */',
           "mesaj")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ1 (server) — _sahaCap + merkezi kapi muafiyeti + 6 uc musterikart")
