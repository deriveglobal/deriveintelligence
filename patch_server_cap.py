# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "SERVER_CAP_V1"

def patch(rel, edits):
    path = os.path.join(BASE, rel)
    with io.open(path, encoding="utf-8") as f: orig = f.read()
    if MARK in orig:
        print("SKIP (zaten var):", rel); return
    s = orig
    for name, old, new in edits:
        c = s.count(old)
        assert c == 1, "ANCHOR %s bulundu=%d (beklenen 1) -> %s" % (name, c, rel)
        s = s.replace(old, new)
    if not os.path.exists(path + ".srvcapbak"):
        with io.open(path + ".srvcapbak", "w", encoding="utf-8") as f: f.write(orig)
    with io.open(path, "w", encoding="utf-8") as f: f.write(s)
    print("OK", rel, "| SERVER_CAP:", s.count(MARK))

# ===== E0: yardimci — client cozumlemesiyle birebir (kisisel liste doluysa o gecerli; bossa rol varsayilani) =====
E0o = '''  function _sahaCap(sess, cap) { if (!sess) return false; if (sess.sahaRole === "admin") return true; const d = Array.isArray(sess.permissions && sess.permissions.departments) ? sess.permissions.departments : []; return (!d.length) ? true : d.includes(cap); }'''
E0n = '''  function _sahaCap(sess, cap) { if (!sess) return false; if (sess.sahaRole === "admin") return true; const d = Array.isArray(sess.permissions && sess.permissions.departments) ? sess.permissions.departments : []; return (!d.length) ? true : d.includes(cap); }
  /* SERVER_CAP_V1 — yonetim ucu capi: admin bypass; kisisel effective liste doluysa YALNIZ onu okur; bossa rol varsayilanina duser (client _yetki ile birebir). _sahaCap'in "bos=hepsi acik" davranisi finans/yonetim uclari icin fazla acik oldugundan bu kullanilir. */
  function _sahaCapRole(sess, cap, defRoles) { if (!sess) return false; if (sess.sahaRole === "admin") return true; const d = Array.isArray(sess.permissions && sess.permissions.departments) ? sess.permissions.departments : []; if (d.length) return d.includes(cap); return Array.isArray(defRoles) && defRoles.includes(sess.sahaRole); }'''

# ===== E1: kokpit (/api/bi/kokpit-data) — rol yerine 'kokpit' capi (manager varsayilan) =====
E1o = '''      // KOKPIT_MOBIL_V1 — intelligence yetkisi VEYA saha manager/admin (mobil Kokpit odası yönetim içindir).
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) {
        const _ss = await requireSahaAccess(request).catch(() => null);
        if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss;
      }'''
E1n = '''      // KOKPIT_MOBIL_V1 — intelligence yetkisi VEYA saha 'kokpit' capi (matris yonetir; manager varsayilan).
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) {
        const _ss = await requireSahaAccess(request).catch(() => null);
        if (_ss && _sahaCapRole(_ss, "kokpit", ["manager"])) session = _ss;  /* SERVER_CAP_V1 */
      }'''

# ===== E2: ceo (/api/brain/*) — rol yerine 'ceo' capi (manager varsayilan) =====
E2o = '''      // CEO_MOBIL_V1 — intelligence yetkisi VEYA saha manager/admin (mobil CEO Assistant odası yönetim içindir).
      let session = await requireModuleAccess(request, 'intelligence').catch(() => null);
      if (!session) {
        const _ss = await requireSahaAccess(request).catch(() => null);
        if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss;
      }'''
E2n = '''      // CEO_MOBIL_V1 — intelligence yetkisi VEYA saha 'ceo' capi (matris yonetir; manager varsayilan).
      let session = await requireModuleAccess(request, 'intelligence').catch(() => null);
      if (!session) {
        const _ss = await requireSahaAccess(request).catch(() => null);
        if (_ss && _sahaCapRole(_ss, "ceo", ["manager"])) session = _ss;  /* SERVER_CAP_V1 */
      }'''

# ===== E3: ebat-ara — yanlis 'musterikart' capi -> dogru 'ebatkart' capi =====
E3o = '''      let ok = s ? true : (ss && _sahaCap(ss, "musterikart"));  /* YETKI_FAZ1 */'''
E3n = '''      let ok = s ? true : (ss && _sahaCapRole(ss, "ebatkart", []));  /* SERVER_CAP_V1 — ebat-ara: dogru 'ebatkart' capi (onceki 'musterikart' yanlisti); admin varsayilan, grant bi_arac_yetki'den de gelir */'''

# ===== E4: ebat-kart — rol yerine 'ebatkart' capi (admin varsayilan; grant korunur) =====
E4o = '''      let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));'''
E4n = '''      let ok = s ? true : (ss && _sahaCapRole(ss, "ebatkart", []));  /* SERVER_CAP_V1 — matris 'ebatkart' capi; admin varsayilan, grant bi_arac_yetki'den de gelir */'''

# ===== E5: rep-aktivite — sabit e-posta yerine 'rep-aktivite' capi (yonetim@ gecici guvenlik agi) =====
E5o = '''          const who = await pool.query("SELECT lower(email::text) e FROM users WHERE id=$1", [U]);
          if (!who.rows.length || who.rows[0].e !== "yonetim@krb.com.tr") { sendJson(response, 403, { error: "Bu bölüm yalnız yönetime özeldir." }); return; }'''
E5n = '''          const who = await pool.query("SELECT lower(email::text) e FROM users WHERE id=$1", [U]);
          const _raOk = _sahaCapRole(session, "rep-aktivite", []) || (who.rows.length && who.rows[0].e === "yonetim@krb.com.tr");  /* SERVER_CAP_V1 — matris 'rep-aktivite' capi (admin varsayilan); yonetim@ gecici guvenlik agi, cap dogrulaninca kaldirilir */
          if (!_raOk) { sendJson(response, 403, { error: "Bu bölüm yalnız yönetime özeldir." }); return; }'''

patch("server_container.mjs", [
    ("E0", E0o, E0n),
    ("E1", E1o, E1n),
    ("E2", E2o, E2n),
    ("E3", E3o, E3n),
    ("E4", E4o, E4n),
    ("E5", E5o, E5n),
])
print("BITTI.")
