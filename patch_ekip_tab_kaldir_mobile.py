# -*- coding: utf-8 -*-
# EKIP_TAB_KALDIR_V1 (mobil) — saha nav'ndan "Ekip" (temsilciler) tab kaldirildi.
#   Ekip yonetimi artik Yönetim konsolunda. vTemsilciler fonksiyonu dokunulmaz;
#   Rapor > Temsilciler alt-sekmesi (rpTemsilciler) ETKILENMEZ — sadece ust nav girisi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "EKIP_TAB_KALDIR_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = '    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Ekip"]] : []),  /* EKIP_RENAME_V1 */'
NEW = '    /* EKIP_TAB_KALDIR_V1 — Ekip, Yönetim konsoluna tasindi; saha nav girisi kaldirildi */'
assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_TAB_KALDIR_V1 (mobil)")
