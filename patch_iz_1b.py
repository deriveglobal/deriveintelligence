import shutil, sys
F = "shells/saha.js"
src = open(F, encoding="utf-8").read(); orig = src
def patch(src, marker, anchor, before=None, after=None):
    if marker in src: print("SKIP:", marker); return src
    n = src.count(anchor)
    if n != 1: print("HATA anchor tekil degil (%d): %s" % (n, marker)); sys.exit(1)
    rep = (before + anchor) if before is not None else (anchor + after)
    print("OK:", marker); return src.replace(anchor, rep, 1)

H1a = 'function setRoom(room) {'
H1 = '''function izBirak(olay, payload) { /* SAHA_IZ_CLIENT_V1 */
  try { api("/api/saha/iz", { method: "POST", body: JSON.stringify({ olay: olay || "goruntule", oda: (S && (S.view || S.room)) || "", payload: payload || {} }) }).catch(function () {}); } catch (e) {}
}
'''
src = patch(src, "SAHA_IZ_CLIENT_V1", H1a, before=H1)

H2a = '  S.room = room;'
H2 = '''  try { if (S && S.room && S.room !== room) izBirak("oda_gecis", { onceki: S.room, yeni: room }); } catch (e) {} /* SAHA_NAV_ODA_V1 */
'''
src = patch(src, "SAHA_NAV_ODA_V1", H2a, before=H2)

H3a = '  S.view = v;'
H3 = '''  try { var _pv = (S && (S.view || S.room)) || null; izBirak("ekran", { onceki: _pv, yeni: v, dwell_ms: (S && S._ekranGiris) ? (Date.now() - S._ekranGiris) : null }); if (S) S._ekranGiris = Date.now(); } catch (e) {} /* SAHA_NAV_EKRAN_V1 */
'''
src = patch(src, "SAHA_NAV_EKRAN_V1", H3a, before=H3)

if src != orig:
    shutil.copy(F, F + ".bak_iz1b"); open(F, "w", encoding="utf-8").write(src); print("YAZILDI + .bak_iz1b")
else: print("Degisiklik yok")
