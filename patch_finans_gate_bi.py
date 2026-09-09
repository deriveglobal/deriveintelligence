# -*- coding: utf-8 -*-
# FINANS_GATE_V1 — BI shell 'Finans Odasi' sekme + oda enjeksiyonu artik dept-gated:
#   permissions.departments 'finansodasi' icermiyorsa GORUNMEZ (price-list/rakip ile ayni mekanizma).
#   Sunucu tarafi requireBiDept('finansodasi') ile birebir (client==server).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/bi.js"
s = open(F, encoding="utf-8").read()
if "FINANS_GATE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# --- A) Sekme butonu (nav template literal icinde) ---
OLD_TAB = '          <button class="vmo-tab" data-dept="finansodasi" style="--c:#059669" title="Finans Odasi" data-mark="FINANS_TAB_V2"><span>💰</span> Finans</button>'
NEW_TAB = '          ${allowedDepts.includes("finansodasi") ? \'<button class="vmo-tab" data-dept="finansodasi" style="--c:#059669" title="Finans Odasi" data-mark="FINANS_TAB_V2"><span>💰</span> Finans</button>\' : \'\'}  /* FINANS_GATE_V1 */'
assert s.count(OLD_TAB) == 1, "TAB anchor bulunamadi (%d)" % s.count(OLD_TAB)
s = s.replace(OLD_TAB, NEW_TAB, 1)

# --- B) Oda enjeksiyon kosulu ---
OLD_ROOM = "if (_o && !document.getElementById('vmo-room-finansodasi')) {"
NEW_ROOM = "if (_o && allowedDepts.includes(\"finansodasi\") && !document.getElementById('vmo-room-finansodasi')) {  /* FINANS_GATE_V1 */"
assert s.count(OLD_ROOM) == 1, "ROOM anchor bulunamadi (%d)" % s.count(OLD_ROOM)
s = s.replace(OLD_ROOM, NEW_ROOM, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] FINANS_GATE_V1 (bi shell: sekme + oda dept-gated)")
