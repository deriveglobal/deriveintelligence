#!/usr/bin/env python3
# saha_fix_1 (omurga_78) — Piyasa dosya yukleme: Excel/CSV/Word kabul + ek SILME route.
# Rep raporu (saha_oneri): "excel dosyasi eklenememektedir" + "eki silebilme secenegi".
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

# 1) MIME allowlist genislet + uzanti fallback
OLD1 = '''      const ALLOWED = ["image/jpeg","image/png","image/webp","image/gif","application/pdf"];
      const mime = String(p.mime || "").toLowerCase().split(";")[0].trim();
      if (!ALLOWED.includes(mime)) { sendJson(response, 400, { error: "Yalnizca resim (JPEG/PNG/WebP/GIF) veya PDF yuklenebilir." }); return; }'''
NEW1 = '''      const ALLOWED = ["image/jpeg","image/png","image/webp","image/gif","application/pdf",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/msword",
        "text/csv","application/csv","text/plain"];
      const EXT_OK = /\\.(xlsx|xlsm|xls|csv|pdf|jpe?g|png|webp|gif|docx?|txt)$/i;
      const mime = String(p.mime || "").toLowerCase().split(";")[0].trim();
      const adUzantiOk = p.dosya_adi && EXT_OK.test(String(p.dosya_adi));
      if (!ALLOWED.includes(mime) && !adUzantiOk) { sendJson(response, 400, { error: "İzin verilmeyen dosya türü. Resim, PDF, Excel (xlsx/xls), CSV veya Word yükleyebilirsiniz." }); return; }'''

# 2) DELETE route ekle (GET-by-id blogundan sonra)
OLD2 = '''      response.writeHead(200, { "Content-Type": r.rows[0].mime || "application/octet-stream", "Cache-Control": "private, max-age=3600", "X-Content-Type-Options": "nosniff" });
      response.end(r.rows[0].veri);
      return;
    }
    if (method === "POST" && path === "/api/saha/rakip-teklif") {'''
NEW2 = '''      response.writeHead(200, { "Content-Type": r.rows[0].mime || "application/octet-stream", "Cache-Control": "private, max-age=3600", "X-Content-Type-Options": "nosniff" });
      response.end(r.rows[0].veri);
      return;
    }
    if (method === "DELETE" && (m = path.match(new RegExp("^/api/saha/piyasa-dosya/(" + SAHA_UUID_RE + ")$")))) {
      const session = await requireSahaAccess(request);
      const own = await query("SELECT rep_id FROM saha_dosya WHERE tenant_id=$1 AND id=$2", [session.tenantId, m[1]]);
      if (!own.rowCount) { sendJson(response, 404, { error: "Dosya bulunamadi." }); return; }
      const yetkili = own.rows[0].rep_id === session.userId || session.moduleRole === "admin" || session.sahaRole === "admin";
      if (!yetkili) { sendJson(response, 403, { error: "Bu dosyayi silme yetkiniz yok." }); return; }
      await query("DELETE FROM saha_dosya WHERE tenant_id=$1 AND id=$2", [session.tenantId, m[1]]);
      sendJson(response, 200, { ok: true });
      return;
    }
    if (method === "POST" && path === "/api/saha/rakip-teklif") {'''

if 'İzin verilmeyen dosya türü' in srv:
    sys.exit("ZATEN VAR: saha_fix_1 uygulanmis gibi.")
for i, (o, n) in enumerate([(OLD1, NEW1), (OLD2, NEW2)], 1):
    if o not in srv:
        sys.exit("HATA: %d. blok bulunamadi (elle bak)." % i)
    if srv.count(o) != 1:
        sys.exit("UYARI: %d. blok %d kez — belirsiz." % (i, srv.count(o)))
    srv = srv.replace(o, n, 1)

shutil.copy2(S, S + ".sahadosya.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".sahadosya.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .sahadosya.bak)")
print("OK: piyasa-dosya Excel/CSV/Word kabul + DELETE route eklendi. saha.js -> shells/, sonra build.")
