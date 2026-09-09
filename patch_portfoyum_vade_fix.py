# -*- coding: utf-8 -*-
# PORTFOYUM_VADE_FIX_V1 — vade regex JS-kaçış bug düzeltmesi
#   Sorun: '(\d+)\s*[Gg]ün' JS template literal içinde → \d→d, \s→s → regex bozuk →
#          "30 Gün Vade" eşleşmiyor → ağırlıklı vade hep 0.
#   Çözüm: backslash'sız POSIX → '([0-9]+)[[:space:]]*[Gg]ün' (JS bozamaz).
#   TÜM occurrences (Portföyüm perSql + varsa ebat-kart vb.) düzeltilir. Idempotent.
#   Rollback .vadefixbak. Fatih: python3 patch_portfoyum_vade_fix.py <dizin>
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
REL  = "server_container.mjs"
path = os.path.join(BASE, REL)
OLD = r"'(\d+)\s*[Gg]ün'"
NEW = r"'([0-9]+)[[:space:]]*[Gg]ün'"
with io.open(path, encoding="utf-8") as f: orig = f.read()
n = orig.count(OLD)
if n == 0:
    print("SKIP (zaten düzeltilmiş — bozuk kalıp yok):", REL); raise SystemExit
s = orig.replace(OLD, NEW)
if not os.path.exists(path + ".vadefixbak"):
    with io.open(path + ".vadefixbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| düzeltilen regex sayısı:", n, "| kalan bozuk:", s.count(OLD))
