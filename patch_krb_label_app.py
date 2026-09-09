# -*- coding: utf-8 -*-
# KRB_LABEL_V1 — "KRB Saha yüklenemedi" -> "Saha yüklenemedi" (modul yukleme hatasi).
#   ASCII anchor (Turkce karakter YOK -> normalizasyon sorunu olmaz).
#   NON-FATAL: anchor bulunmazsa deploy'u DURDURMAZ (kozmetik). exit 0.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "app.js"
s = open(F, encoding="utf-8").read()
if "KRB_LABEL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = '>KRB Saha '          # class="platform-error">KRB Saha yüklenemedi...
NEW = '>Saha '              # + marker ayri yorumda
n = s.count(OLD)
if n != 1:
    print("[atla] KRB anchor bulunamadi (%d) — kozmetik, deploy devam" % n); sys.exit(0)
s = s.replace(OLD, NEW, 1)
# marker'i ayri, guvenli bir noktaya (dosya sonu yorumu) koy ki idempotent olsun
s = s + "\n/* KRB_LABEL_V1 */\n"
open(F, "w", encoding="utf-8").write(s)
print("[done] KRB_LABEL_V1")
