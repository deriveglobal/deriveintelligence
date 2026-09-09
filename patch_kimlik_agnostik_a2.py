#!/usr/bin/env python3
import sys, shutil
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
MARK = "TENANT_KIMLIK_AGNOSTIK_A2"
s = open(PATH, encoding="utf-8").read()
if MARK in s:
    print("[=] Marker zaten var — A2 uygulanmis, cikiliyor (idempotent).")
    sys.exit(0)
REPL = [
  ('          const _gl = await query("SELECT ts::date AS t, COALESCE(ne, adim) AS ne FROM bi_insa_gunlugu ORDER BY ts DESC LIMIT 8", []);\n',
   "          /* " + MARK + " — bi_insa_gunlugu (KRB insa gecmisi) tenant CEO prompt'undan cikarildi */\n"),
  ("            '\\nSon yapilan isler (insa gunlugu):\\n' +\n"
   "            (_gl.rows.length ? _gl.rows.map(function (r) { return '- ' + r.t + ' - ' + r.ne; }).join('\\n') : '(kayit yok)') +\n",
   ""),
]
for i, (old, new) in enumerate(REPL, 1):
    c = s.count(old)
    if c != 1:
        print(f"[!] HATA: R{i} anchor {c} kez bulundu (1 olmali). Patch iptal, dosya DEGISMEDI.")
        sys.exit(1)
bak = PATH + ".bak_kimlik_a2"
shutil.copy2(PATH, bak)
print(f"[+] Yedek: {bak}")
for i, (old, new) in enumerate(REPL, 1):
    s = s.replace(old, new, 1); print(f"[+] R{i} uygulandi.")
open(PATH, "w", encoding="utf-8").write(s)
print(f"[OK] {MARK} uygulandi. node --check calistir.")
