# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# MESAJLAR_FIX — two real bugs found from Eftal's ticket:
#
# 1) saha_konusma.tip CHECK allows only ('BIREYSEL','YAYIM'), but the code writes
#    'rep-manager' / 'yayim'. A rep with no conversation row yet (Eftal) hits the
#    INSERT, the CHECK rejects it, and the Mesajlar tab errors. Rep-only, because
#    the manager branch never inserts.
#
# 2) log-hata inserts tenant_id='00000000-...' which is an FK to platform_tenants
#    and does not exist -> every client error insert fails the FK and is swallowed
#    by catch(_){}. The error logger has been silently discarding everything.
#    Resolve the real session (the client already sends the auth header); fall back
#    to NULL rather than a fake UUID.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep_all(a, b, tag, minimum=1):
    global s
    c = s.count(a)
    assert c >= minimum, "ABORT [%s]: found %d (need >=%d)" % (tag, c, minimum)
    s = s.replace(a, b); print("OK: %s (%d occurrence(s))" % (tag, c))

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) conversation type must match the CHECK constraint
rep_all("'rep-manager'", "'BIREYSEL'", "konusma-tip-bireysel")
rep_all("'yayim'", "'YAYIM'", "konusma-tip-yayim")

# 2) error logger: use the real tenant/user instead of a non-existent UUID
rep(
'''    if (method === "POST" && path === "/api/saha/log-hata") {
      // Sessiz hata logu — auth gerekmez
      try {
        const body = await readJson(request);
        const { tip, view_adi, endpoint, http_status, hata_mesaji, duration_ms, extra } = body;
        await pool.query(
          `INSERT INTO saha_hata_log (id,tenant_id,user_id,tip,view_adi,endpoint,http_status,hata_mesaji,duration_ms,extra)
           VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8,$9)`,
          ['00000000-0000-0000-0000-000000000000', null, tip||'client', view_adi||null,
           endpoint||null, http_status||null, hata_mesaji||null, duration_ms||null,
           extra ? JSON.stringify(extra) : null]
        );
      } catch(_) {}''',
'''    if (method === "POST" && path === "/api/saha/log-hata") {
      // Sessiz hata logu — auth zorunlu degil, ama varsa gercek tenant/user'i kullan.
      // (Onceki hali sahte bir UUID yaziyordu; tenant_id FK oldugu icin HER insert
      //  sessizce dusuyordu ve hata kaydi hic tutulmuyordu.)
      try {
        const body = await readJson(request);
        const { tip, view_adi, endpoint, http_status, hata_mesaji, duration_ms, extra } = body;
        let _tid = null, _uid = null;
        try { const _s = await requireSahaAccess(request); _tid = _s.tenantId || null; _uid = _s.userId || null; } catch (_) {}
        await pool.query(
          `INSERT INTO saha_hata_log (id,tenant_id,user_id,tip,view_adi,endpoint,http_status,hata_mesaji,duration_ms,extra)
           VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8,$9)`,
          [_tid, _uid, tip||'client', view_adi||null,
           endpoint||null, http_status||null, hata_mesaji||null, duration_ms||null,
           extra ? JSON.stringify(extra) : null]
        );
      } catch (e) { console.error("[log-hata]", e && e.message); }''',
    "log-hata-real-tenant")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
