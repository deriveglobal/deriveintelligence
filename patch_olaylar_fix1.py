# -*- coding: utf-8 -*-
# MUSTERI_OLAYLAR_FIX1 (server) — uuid=text tuzağı düzeltmesi.
#   /olaylar cr sorgusunda sg.tenant_id=$1::text $1'i text'e sabitliyor → m.tenant_id=$1 (uuid=text) patlıyor.
#   Çözüm: m.tenant_id::text=$1::text (devir kuralı: tüm tenant karşılaştırmalarını ::text yap).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MUSTERI_OLAYLAR_FIX1" in s:
    print("[skip] zaten fix'li"); sys.exit(0)

old = "       WHERE m.tenant_id=$1 AND m.id=$2 AND m.aktif=true`, [tid, mid]);"
new = "       WHERE m.tenant_id::text=$1::text AND m.id=$2 AND m.aktif=true`, [tid, mid]);  /* MUSTERI_OLAYLAR_FIX1 */"
assert s.count(old) == 1, "anchor=%d" % s.count(old)
s = s.replace(old, new, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_OLAYLAR_FIX1 — m.tenant_id::text=$1::text")
