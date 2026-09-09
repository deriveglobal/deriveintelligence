# -*- coding: utf-8 -*-
# REP_PARITE_V1 (server) — saha temsilcisini (rep) müşteri kartında yöneticiyle aynı bilgiye açar.
#   Yalnız şu endpoint'lerin manager/admin kapısını GEVŞETİR (auth yine zorunlu — requireSahaAccess/_sess kalır):
#     /api/bi/musteri-skor, /api/bi/musteri-fiyat-liste, /api/bi/musteri-kiyas, /api/bi/ebat-ara,
#     /api/saha/ai/musteri-ozeti/:id, /api/saha/musteri/:id/mesaj
#   Diğer aynı guard'lı endpoint'lere (marj-alarm, musteri-fiyat, iyilestirme-hedefleri, ebat-kart, marj-alarm-desen) DOKUNMAZ.
#   Hedefli: her endpoint'in kendi pathname'ini bulur, ONDAN SONRAKİ ilk guard satırını değiştirir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "REP_PARITE_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

def swap_after(marker, old, new, why):
    """marker'dan SONRAKİ ilk old'u new ile değiştir (tek sefer)."""
    global s
    i = s.find(marker)
    assert i != -1, "marker yok: %s" % why
    j = s.find(old, i)
    assert j != -1, "old bulunamadı: %s" % why
    s = s[:j] + new + s[j+len(old):]

GUARD = 'if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }'
def open_bi(pathname):
    new = '/* REP_PARITE_V1 — %s saha rolune acildi (auth: yukaridaki !_sess kontrolu yeterli) */' % pathname
    swap_after('url.pathname === "%s"' % pathname, GUARD, new, pathname)

# 1-3) skor / fiyat-liste / kiyas — manager/admin guard'ını kaldır
open_bi("/api/bi/musteri-skor")
open_bi("/api/bi/musteri-fiyat-liste")
open_bi("/api/bi/musteri-kiyas")

# 4) ebat-ara — 'let ok' satırını saha rolüne aç (ebat-kart'a DOKUNMA: onun pathname'i farklı)
swap_after('url.pathname === "/api/bi/ebat-ara"',
           'let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));',
           'let ok = s ? true : !!ss;  /* REP_PARITE_V1 — ebat-ara saha rolune acildi */',
           "ebat-ara")

# 5) AI özet — requireSahaAccess rol filtresini kaldır (boşluklu varyant)
swap_after('/api/saha/ai/musteri-ozeti/',
           'const session = await requireSahaAccess(request, ["manager", "admin"]);',
           'const session = await requireSahaAccess(request);  /* REP_PARITE_V1 — AI ozet saha rolune acildi */',
           "ai-ozet")

# 6) mesaj — requireSahaAccess rol filtresini kaldır (boşluksuz varyant)
swap_after('([^/]+)\\/mesaj$/',
           'const session = await requireSahaAccess(request, ["manager","admin"]);',
           'const session = await requireSahaAccess(request);  /* REP_PARITE_V1 — musteri mesaj saha rolune acildi */',
           "mesaj")

open(F, "w", encoding="utf-8").write(s)
print("[done] REP_PARITE_V1 (server) — 6 endpoint saha rolune acildi")
