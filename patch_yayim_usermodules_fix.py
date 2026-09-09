# -*- coding: utf-8 -*-
# YAYIM_USERMODULES_FIX_V1 — "Toplu Mesaj Gonder" (/api/saha/konusmalar/yayim) alici
#   sorgusu OLMAYAN 'user_modules' tablosuna JOIN yapiyordu -> "relation user_modules
#   does not exist" hatasi. Dogru tablo: tenant_user_modules (module_id + tenant_id + active).
#   Ayrica $1 (tenantId) parametresi hic kullanilmiyordu; artik tenant filtresi uygulanir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YAYIM_USERMODULES_FIX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = "          JOIN user_modules um ON um.user_id=u.id AND um.module='saha'"
NEW = "          JOIN tenant_user_modules um ON um.user_id=u.id AND um.module_id='saha' AND um.tenant_id=$1 AND um.active=true  /* YAYIM_USERMODULES_FIX_V1 */"
assert s.count(OLD) == 1, "anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_USERMODULES_FIX_V1")
