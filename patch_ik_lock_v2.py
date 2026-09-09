# -*- coding: utf-8 -*-
# IK_LOCK_V2 - requireBiDept: ikodasi icin modul-admin bypass kapali (dort IK ucu birden)
import io,os,sys,base64,json
F=sys.argv[1] if len(sys.argv)>1 else "server_container.mjs"
D=json.loads('[["ICBpZiAobm9ybWFsaXplUm9sZShzZXNzaW9uLnJvbGUpID09PSAicGxhdGZvcm1fb3duZXIiKSByZXR1cm4gc2Vzc2lvbjsKICBpZiAoc2Vzc2lvbi5tb2R1bGVSb2xlID09PSAiYWRtaW4iKSByZXR1cm4gc2Vzc2lvbjsKICBjb25zdCBwZXJtcyA9IHNlc3Npb24ucGVybWlzc2lvbnMgfHwge307", "ICBpZiAobm9ybWFsaXplUm9sZShzZXNzaW9uLnJvbGUpID09PSAicGxhdGZvcm1fb3duZXIiKSByZXR1cm4gc2Vzc2lvbjsKICBpZiAoc2Vzc2lvbi5tb2R1bGVSb2xlID09PSAiYWRtaW4iICYmIGRlcHQgIT09ICJpa29kYXNpIikgcmV0dXJuIHNlc3Npb247ICAvKiBJS19MT0NLX1YyIC0gaWtvZGFzaSBhZG1pbi1ieXBhc3Mga2FwYWxpOyB5YWxuaXogcGxhdGZvcm1fb3duZXIgKyBkZXBhcnRtZW50cy5pa29kYXNpICovCiAgY29uc3QgcGVybXMgPSBzZXNzaW9uLnBlcm1pc3Npb25zIHx8IHt9Ow=="]]')
s=io.open(F,encoding="utf-8").read()
if "IK_LOCK_V2" in s:
    print("ZATEN VAR - IK_LOCK_V2, atlandi"); sys.exit(0)
for o64,n64 in D:
    o=base64.b64decode(o64).decode(); n=base64.b64decode(n64).decode()
    if n in s and o not in s: continue
    c=s.count(o); assert c==1, "anchor=%d :: %s"%(c,o[:60])
    s=s.replace(o,n,1)
if not os.path.exists(F+".iklockv2bak"):
    io.open(F+".iklockv2bak","w",encoding="utf-8").write(io.open(F,encoding="utf-8").read())
io.open(F,"w",encoding="utf-8").write(s)
print("OK IK_LOCK_V2 - requireBiDept ikodasi kilidi")
