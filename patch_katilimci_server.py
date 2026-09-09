import sys, io
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
if "KATILIMCI_V1" in s:
    print("[katilimci_server] zaten uygulanmis, atlaniyor."); sys.exit(0)
O='    if (method === "GET" && path === "/api/saha/reps") {'
N='''    if (method === "GET" && path === "/api/saha/saha-kullanicilar") { // KATILIMCI_V1 — tum saha kullanicilari (rep dahil erisir)
      const session = await requireSahaAccess(request);
      const rows = await pool.query(
        `SELECT u.id, COALESCE(u.full_name, u.email) AS ad FROM users u
           JOIN tenant_user_modules tum ON tum.user_id = u.id AND tum.module_id = 'saha' AND tum.tenant_id = $1 AND tum.active = true
          WHERE u.status != 'disabled' ORDER BY ad`,
        [session.tenantId]);
      sendJson(response, 200, { kullanicilar: rows.rows });
      return;
    }
    if (method === "GET" && path === "/api/saha/reps") {'''
if s.count(O)!=1:
    sys.stderr.write("[server] HATA anchor=%d\n"%s.count(O)); sys.exit(2)
io.open(p,"w",encoding="utf-8").write(s.replace(O,N,1))
print("[katilimci_server] uygulandi.")
