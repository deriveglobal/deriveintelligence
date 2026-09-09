#!/usr/bin/env python3
# DSO_TOKENS_FIX — DSO anlati AI cevabi max_tokens 420 -> 760 (Turkce token-agir: sinifsiz cumlesi
#   ortada kesiliyordu). Sadece DSO blogundaki sonnet cagrisini hedefler (tekil string). Idempotent.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
OLD = 'model: "claude-sonnet-4-6", max_tokens: 420,'
NEW = 'model: "claude-sonnet-4-6", max_tokens: 760,'
if OLD not in s:
    if NEW in s:
        print("[skip] DSO_TOKENS_FIX zaten uygulanmis (760)"); sys.exit(0)
    print("HATA: hedef string bulunamadi (DSO blogu?)"); sys.exit(1)
assert s.count(OLD) == 1, "HATA: hedef tekil degil (%d) — elle kontrol et" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[ok] DSO_TOKENS_FIX — DSO anlati max_tokens 420 -> 760")
