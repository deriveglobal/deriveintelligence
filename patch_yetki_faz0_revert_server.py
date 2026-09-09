# -*- coding: utf-8 -*-
# YETKI_FAZ0 (server) — REP_PARITE_V1'i GERİ AL. 6 ucun manager/admin kapısını eski hâline döndürür.
#   (V2 hiç deploy edilmedi; burada V2 yok.) Faz 1'de zorlama tek choke point'e matris-tabanlı toplanacak.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "REP_PARITE_V1" not in s:
    print("[skip] REP_PARITE_V1 izi yok — zaten temiz"); sys.exit(0)

def rep(old, new, why):
    global s
    n = s.count(old)
    assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

GUARD = 'if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }'
# 1-3) skor / fiyat-liste / kiyas — comment'i eski guard'a döndür
for pth in ("/api/bi/musteri-skor", "/api/bi/musteri-fiyat-liste", "/api/bi/musteri-kiyas"):
    rep('/* REP_PARITE_V1 — %s saha rolune acildi (auth: yukaridaki !_sess kontrolu yeterli) */' % pth,
        GUARD, "guard:" + pth)
# 4) ebat-ara
rep('let ok = s ? true : !!ss;  /* REP_PARITE_V1 — ebat-ara saha rolune acildi */',
    'let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));', "ebat-ara")
# 5) AI özet
rep('const session = await requireSahaAccess(request);  /* REP_PARITE_V1 — AI ozet saha rolune acildi */',
    'const session = await requireSahaAccess(request, ["manager", "admin"]);', "ai-ozet")
# 6) mesaj
rep('const session = await requireSahaAccess(request);  /* REP_PARITE_V1 — musteri mesaj saha rolune acildi */',
    'const session = await requireSahaAccess(request, ["manager","admin"]);', "mesaj")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ0 (server) — REP_PARITE_V1 geri alindi")
