# -*- coding: utf-8 -*-
# RISK_SAHA_FIX1 (server) — "operator does not exist: uuid = text" düzeltmesi.
#   CTE'de $1::text kullanıldığı için PG $1'i TEXT tipliyor; sonra m.tenant_id (uuid) = $1 (text) patlıyor.
#   Çözüm: m.tenant_id karşılaştırmasını da ::text ile eşitle (tutarlı text karşılaştırması).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RISK_SAHA_FIX1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "RISK_SAHA_V1" in s, "HATA: once RISK_SAHA_V1 olmali"

o = "         WHERE m.tenant_id = $1 AND m.aktif = true AND m.musteri_kodu IS NOT NULL${tipSql}${repSql}"
n = "         WHERE m.tenant_id::text = $1::text AND m.aktif = true AND m.musteri_kodu IS NOT NULL${tipSql}${repSql}  /* RISK_SAHA_FIX1 */"
assert s.count(o) == 1, "anchor=%d" % s.count(o)
s = s.replace(o, n, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RISK_SAHA_FIX1 (server)")
