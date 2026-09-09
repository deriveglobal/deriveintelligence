#!/usr/bin/env python3
import shutil, subprocess, sys
B = "/opt/krb-assessment/shells/bi.js"
js = open(B, encoding="utf-8").read()
OLD = '<button class="vmo-tab" data-dept="finans" style="--c:#8A8A8F">Finans</button>'
NEW = '<button class="vmo-tab" data-dept="finans" style="--c:#8A8A8F">Kokpit</button>'
if '>Kokpit</button>' in js and OLD not in js: sys.exit("ZATEN VAR")
if js.count(OLD) != 1: sys.exit("HATA: eslesme %d" % js.count(OLD))
shutil.copy2(B, B + ".tab.bak")
open(B, "w", encoding="utf-8").write(js.replace(OLD, NEW, 1))
print("OK: Finans -> Kokpit (data-dept='finans' degismedi)")
