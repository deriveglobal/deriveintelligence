import sys
F=sys.argv[1] if len(sys.argv)>1 else "server_container.mjs"
s=open(F,encoding="utf-8").read()
if "email: session.email, globalRole:" in s:
    print("[skip] zaten var"); sys.exit(0)
OLD="name: session.name, globalRole:"
n=s.count(OLD)
assert n==3, "beklenmeyen occurrence sayisi: %d (3 bekleniyordu)"%n
s=s.replace(OLD, "name: session.name, email: session.email, globalRole:")
open(F,"w",encoding="utf-8").write(s)
print("[ok] /api/platform/me email alani eklendi (%d yer)"%n)
