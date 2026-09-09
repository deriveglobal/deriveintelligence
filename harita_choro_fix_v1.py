#!/usr/bin/env python3
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "_choroGeo" in s:
    print("choro-fix: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_CHORO_V1" in s, "HARITA_CHORO_V1 yok"

A1 = '    let _choroLayer = null, _trGeo = null, _ilMetrik = null, _ilMetrikDonem = null, _haritaMapRef = null, _choroMetrik = "";\n'
assert s.count(A1) == 1, "choro decl anchor"
N1 = '    let _choroLayer = null, _choroGeo = null, _ilMetrik = null, _ilMetrikDonem = null, _haritaMapRef = null, _choroMetrik = ""; /* HARITA_CHORO_FIX_V1 */\n'
s = s.replace(A1, N1, 1)

A2 = '    async function _ensureTrGeo() { if (_trGeo) return _trGeo; _trGeo = await api("/api/saha/tr-geo"); return _trGeo; }\n'
assert s.count(A2) == 1, "_ensureTrGeo anchor"
N2 = '    async function _ensureTrGeo() { if (_choroGeo) return _choroGeo; _choroGeo = await api("/api/saha/tr-geo"); return _choroGeo; }\n'
s = s.replace(A2, N2, 1)

write(FP, s)
print("choro-fix: choro _trGeo -> _choroGeo (cakisma kaldirildi)")
print("kalan 'let _trGeo':", s.count("let _trGeo"))
print("DONE.")
