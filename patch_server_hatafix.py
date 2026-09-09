import sys, io
p = sys.argv[1]; s = io.open(p, encoding="utf-8").read()
if "KONUSMA_YAYIM_FIX_V1" in s:
    print("[patch_server_hatafix] zaten uygulanmis, atlaniyor."); sys.exit(0)

O1 = """          JOIN user_modules um ON um.user_id=u.id AND um.module='saha'
          WHERE u.status != 'disabled'`,"""
N1 = """          JOIN tenant_user_modules um ON um.user_id=u.id AND um.module_id='saha' AND um.active AND um.tenant_id=$1 /* KONUSMA_YAYIM_FIX_V1 */
          WHERE u.status != 'disabled'`,"""

O2 = """/foto$`)))) {
      const session = await requireSahaAccess(request);
      const p = await readJson(request);
      if (!p.data) { sendJson(response, 400, { error: "data (base64) zorunlu." }); return; }"""
N2 = """/foto$`)))) {
      const session = await requireSahaAccess(request);
      const p = await readJson(request, 8 * 1024 * 1024); // ZIYARET_FOTO_LIMIT_V1 — 512KB varsayilan foto icin yetmiyordu
      if (!p.data) { sendJson(response, 400, { error: "data (base64) zorunlu." }); return; }"""

for i,(o,n) in enumerate([(O1,N1),(O2,N2)]):
    if s.count(o) != 1:
        sys.stderr.write("[patch_server_hatafix] HATA edit %d anchor=%d (1 bekleniyordu)\n" % (i,s.count(o))); sys.exit(2)
    s = s.replace(o,n,1)
io.open(p,"w",encoding="utf-8").write(s)
print("[patch_server_hatafix] uygulandi (2 edit).")
