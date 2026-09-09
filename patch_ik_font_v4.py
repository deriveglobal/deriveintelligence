# -*- coding: utf-8 -*-
# IK_FONT_V4 — İK Odası kart/portre yazi olcegini kucultur (yalniz CSS)
import io,os,sys,base64
BASE=sys.argv[1] if len(sys.argv)>1 else "."
CLI=os.path.join(BASE,"shells","ik.html")
ANC=base64.b64decode("PC9zdHlsZT48L2hlYWQ+PGJvZHk+").decode()
NEW=base64.b64decode("LyogSUtfRk9OVF9WNCDigJQgZ2VuZWwgeWF6aSBvbGNlZ2kga3VjdWx0dWxkdSAqLwoudG9wIGgxe2ZvbnQtc2l6ZToxN3B4fQoubWt7Zm9udC1zaXplOjE4cHh9Ci5wdCAudntmb250LXNpemU6MjJweH0KLm5vZGUgLm5te2ZvbnQtc2l6ZToxM3B4fQoubm9kZSAuYXJjaHtmb250LXNpemU6MTFweH0KLm5vZGUgLnNuaXB7Zm9udC1zaXplOjExLjVweDtsaW5lLWhlaWdodDoxLjQ7bWFyZ2luLXRvcDo4cHh9Ci5ub2RlIC5tb217Zm9udC1zaXplOjEycHh9Ci5kcmhkIC5ubXtmb250LXNpemU6MTlweH0KLnJlYWR7Zm9udC1zaXplOjEyLjVweDtsaW5lLWhlaWdodDoxLjU1fQoucmVhZGZ1bGwgcHtmb250LXNpemU6MTIuNXB4O2xpbmUtaGVpZ2h0OjEuNTV9Ci5zaWcgLnR4e2ZvbnQtc2l6ZToxMnB4fQouZXYgLmNse2ZvbnQtc2l6ZToxMi41cHh9Ci5maW5kIC5ie2ZvbnQtc2l6ZToxMi41cHh9Ci5hY3R7Zm9udC1zaXplOjEyLjVweH0KPC9zdHlsZT48L2hlYWQ+PGJvZHk+").decode()
s=io.open(CLI,encoding="utf-8").read()
if "IK_FONT_V4" in s:
    print("ZATEN VAR — IK_FONT_V4 mevcut, atlandi"); sys.exit(0)
c=s.count(ANC); assert c==1, "anchor sayisi=%d beklenen 1" % c
s=s.replace(ANC,NEW,1)
if not os.path.exists(CLI+".fontbak"):
    io.open(CLI+".fontbak","w",encoding="utf-8").write(io.open(CLI,encoding="utf-8").read())
io.open(CLI,"w",encoding="utf-8").write(s)
print("OK IK_FONT_V4 — shells/ik.html guncellendi")
