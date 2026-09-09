# -*- coding: utf-8 -*-
# SEKME_CAP_SRV_V1 (server_container.mjs) — Saha ROI + Portfoy uclarini kendi capability'sine bagla.
#   ziyaret-etki ['rapor']->['etki'] · portfoy ['rapor']->['portfoy']. Client _rNEW ile birebir; backfill sonrasi
#   dolu-departments kullanicilar etki/portfoy tasidigindan gecerler, bos-departments rol-fallback (degismedi), admin bypass.
#   Pipeline/Pazar paylasimli rapor uclarini (rapor/teklif, rapor/rakip, rapor/bolge-marka) cagirir -> onlar view-cap
#   (client gizler) olarak birakildi; sert server-gate ozel uc gerektirir (ileride). Bu yama regresyonsuz + gercek.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SEKME_CAP_SRV_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ETKI_OLD = '    "/api/saha/rapor/ziyaret-etki": ["rapor"],  /* ZIYARET_ETKI_V1 */'
assert s.count(ETKI_OLD) == 1, "ziyaret-etki anchor=%d" % s.count(ETKI_OLD)
s = s.replace(ETKI_OLD, '    "/api/saha/rapor/ziyaret-etki": ["etki"],  /* SEKME_CAP_SRV_V1 */  /* ZIYARET_ETKI_V1 */', 1)

PORT_OLD = '    "/api/saha/rapor/portfoy": ["rapor"],  /* PORTFOY_V1 */'
assert s.count(PORT_OLD) == 1, "portfoy anchor=%d" % s.count(PORT_OLD)
s = s.replace(PORT_OLD, '    "/api/saha/rapor/portfoy": ["portfoy"],  /* SEKME_CAP_SRV_V1 */  /* PORTFOY_V1 */', 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SEKME_CAP_SRV_V1 (server) — ziyaret-etki->etki, portfoy->portfoy")
