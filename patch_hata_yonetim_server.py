import sys
F=sys.argv[1] if len(sys.argv)>1 else "server_container.mjs"
s=open(F,encoding="utf-8").read()
if "HATA_YONETIM_V1" in s: print("[skip] zaten var"); sys.exit(0)
A='''      if (normalizeRole(session.role) !== "platform_owner") {
        sendJson(response, 403, { error: "Bu bölüm platform yönetimine özeldir." });
        return;
      }'''
assert s.count(A)==1, "server anchor: %d"%s.count(A)
B='''      if (normalizeRole(session.role) !== "platform_owner" && String(session.email || "").toLowerCase() !== "yonetim@krb.com.tr") { /* HATA_YONETIM_V1 */
        sendJson(response, 403, { error: "Bu bölüm platform yönetimine özeldir." });
        return;
      }'''
s=s.replace(A,B,1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] HATA_YONETIM_V1 server (hata-raporu gate yonetim'e acildi)")
