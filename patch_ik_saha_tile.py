# -*- coding: utf-8 -*-
# IK_SAHA_TILE_V1 - mobil resepsiyona cap-kapili IK Odasi karti (YALNIZ departments.ikodasi)
import io,os,sys,base64,json
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
D=json.loads('[["ICB9OwogIGluamVjdFN0eWxlcygpOw==", "ICB9OwogIFMuaWtvZGFzaSA9IChmdW5jdGlvbigpeyB0cnkgeyB2YXIgX2lzID0gKG1lLnN1YnNjcmlwdGlvbnN8fFtdKS5maW5kKGZ1bmN0aW9uKHgpe3JldHVybiB4Lm1vZHVsZUlkPT09ImludGVsbGlnZW5jZSI7fSk7IHZhciBfZCA9IChfaXMgJiYgX2lzLnBlcm1pc3Npb25zICYmIEFycmF5LmlzQXJyYXkoX2lzLnBlcm1pc3Npb25zLmRlcGFydG1lbnRzKSkgPyBfaXMucGVybWlzc2lvbnMuZGVwYXJ0bWVudHMgOiBbXTsgcmV0dXJuIF9kLmluZGV4T2YoImlrb2Rhc2kiKT49MDsgfSBjYXRjaChlKXsgcmV0dXJuIGZhbHNlOyB9IH0pKCk7IC8qIElLX1NBSEFfVElMRV9WMSDigJQgYmkuanMgaWxlIGF5bmk6IHlhbG5peiBkZXBhcnRtZW50cy5pa29kYXNpICovCiAgaW5qZWN0U3R5bGVzKCk7"], ["ICAgIC4uLihfbWdtdCA/IFtbImtva3BpdCIsICLwn5OKIiwgIktva3BpdCIsICJGaW5hbnMga29rcGl0aSDCtyB2aXRhbHMgwrcgacOnZ8O2csO8IiwgIiMwODkxYjIiXSwgWyJjZW8iLCAi8J+noCIsICJDRU8gQXNzaXN0YW50IiwgIkJleWluIMK3IHNvciDCtyBhbmFsaXogwrcgZ8O2cmV2IHZlciIsICIjN2MzYWVkIl1dIDogW10p", "ICAgIC4uLihfbWdtdCA/IFtbImtva3BpdCIsICLwn5OKIiwgIktva3BpdCIsICJGaW5hbnMga29rcGl0aSDCtyB2aXRhbHMgwrcgacOnZ8O2csO8IiwgIiMwODkxYjIiXSwgWyJjZW8iLCAi8J+noCIsICJDRU8gQXNzaXN0YW50IiwgIkJleWluIMK3IHNvciDCtyBhbmFsaXogwrcgZ8O2cmV2IHZlciIsICIjN2MzYWVkIl1dIDogW10pLAogICAgLi4uKFMuaWtvZGFzaSA/IFtbImlrb2Rhc2kiLCAi8J+RpSIsICLEsEsgT2Rhc8SxIiwgIkVraXAgb3JnYW5pem1hc8SxIMK3IG5hYsSxeiDCtyBrb8OnbHVrIiwgIiM3YzNhZWQiXV0gOiBbXSkgLyogSUtfU0FIQV9USUxFX1YxICov"], ["ICBpZiAocm9vbSA9PT0gImtva3BpdCIpICAgIHsgbS5zdHlsZS5wYWRkaW5nID0gIjAiOyB2S29rcGl0TW9iaWwoKTsgcmV0dXJuOyB9", "ICBpZiAocm9vbSA9PT0gImtva3BpdCIpICAgIHsgbS5zdHlsZS5wYWRkaW5nID0gIjAiOyB2S29rcGl0TW9iaWwoKTsgcmV0dXJuOyB9CiAgaWYgKHJvb20gPT09ICJpa29kYXNpIikgICB7IG0uc3R5bGUucGFkZGluZyA9ICIwIjsgdklrT2Rhc2lNb2JpbCgpOyByZXR1cm47IH0gLyogSUtfU0FIQV9USUxFX1YxICov"], ["ZnVuY3Rpb24gcmVuZGVyUmVjZXB0aW9uKCkgew==", "ZnVuY3Rpb24gdklrT2Rhc2lNb2JpbCgpeyAvKiBJS19TQUhBX1RJTEVfVjEgKi8gdmFyIF9tPW1haW4oKTsgX20uc3R5bGUucGFkZGluZz0iMCI7IF9tLnNjcm9sbFRvcD0wOyBfbS5pbm5lckhUTUw9JzxpZnJhbWUgc3JjPSIvYXBpL2JpL2lrLW9kYXNpIiB0aXRsZT0ixLBLIE9kYXPEsSIgc3R5bGU9IndpZHRoOjEwMCU7aGVpZ2h0OjEwMCU7bWluLWhlaWdodDo4MnZoO2JvcmRlcjowO2Rpc3BsYXk6YmxvY2s7YmFja2dyb3VuZDojMGEwZTE0Ij48L2lmcmFtZT4nOyB9CmZ1bmN0aW9uIHJlbmRlclJlY2VwdGlvbigpIHs="]]')
s=io.open(F,encoding="utf-8").read()
if "IK_SAHA_TILE_V1" in s:
    print("ZATEN VAR - IK_SAHA_TILE_V1, atlandi"); sys.exit(0)
for o64,n64 in D:
    o=base64.b64decode(o64).decode(); n=base64.b64decode(n64).decode()
    if n in s and o not in s: continue
    c=s.count(o); assert c==1, "anchor=%d :: %s"%(c,o[:50])
    s=s.replace(o,n,1)
if not os.path.exists(F+".iktilebak"):
    io.open(F+".iktilebak","w",encoding="utf-8").write(io.open(F,encoding="utf-8").read())
io.open(F,"w",encoding="utf-8").write(s)
print("OK IK_SAHA_TILE_V1 - shells/saha.js")
