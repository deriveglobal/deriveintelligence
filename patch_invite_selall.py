# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "INVITE_SELALL_V1"
REL = "shells/tenant-admin.js"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit

OLD1 = r'''    const modSel = content.querySelector("#inv-mod"), roleSel = content.querySelector("#inv-role"), subsBox = content.querySelector("#inv-subs");
    const syncMod = () => {
      const cfg = MODULES[modSel.value];
      roleSel.innerHTML = cfg ? cfg.roles.map(r => `<option value="${r[0]}">${esc(r[1])}</option>`).join("") : `<option value="">—</option>`;
      roleSel.disabled = !cfg;
      subsBox.innerHTML = cfg ? `<label class="ta-lbl">Alt-araç / bölüm erişimi</label><div class="ta-subgrid">${cfg.groups.flatMap(g => g[1]).map(t => `<label class="ta-chk"><input type="checkbox" class="inv-sub" value="${t[0]}"> ${esc(t[1])}</label>`).join("")}</div>` : "";
    };
    modSel.addEventListener("change", syncMod); syncMod();'''

NEW1 = r'''    const modSel = content.querySelector("#inv-mod"), roleSel = content.querySelector("#inv-role"), subsBox = content.querySelector("#inv-subs");
    const updSubCount = () => { const el = content.querySelector("#inv-subcount"); if (!el) return; const all = subsBox.querySelectorAll(".inv-sub").length, on = subsBox.querySelectorAll(".inv-sub:checked").length; el.textContent = on + "/" + all + " seçili"; };
    const syncMod = () => { /* INVITE_SELALL_V1 */
      const cfg = MODULES[modSel.value];
      roleSel.innerHTML = cfg ? cfg.roles.map(r => `<option value="${r[0]}">${esc(r[1])}</option>`).join("") : `<option value="">—</option>`;
      roleSel.disabled = !cfg;
      if (!cfg) { subsBox.innerHTML = ""; return; }
      const items = cfg.groups.flatMap(g => g[1]).map(t => `<label class="ta-chk"><input type="checkbox" class="inv-sub" value="${t[0]}"><span>${esc(t[1])}</span></label>`).join("");
      subsBox.innerHTML = `<div class="ta-subhead"><label class="ta-lbl" style="margin:18px 0 0">Alt-araç / bölüm erişimi</label><div class="ta-subtools"><span class="ta-subcount" id="inv-subcount"></span><button type="button" class="ta-chip" id="inv-all">Tümünü seç</button><button type="button" class="ta-chip" id="inv-none">Temizle</button></div></div><div class="ta-subgrid">${items}</div>`;
      const setAll = v => { subsBox.querySelectorAll(".inv-sub").forEach(c => { c.checked = v; }); updSubCount(); };
      subsBox.querySelector("#inv-all").onclick = () => setAll(true);
      subsBox.querySelector("#inv-none").onclick = () => setAll(false);
      subsBox.querySelectorAll(".inv-sub").forEach(c => c.addEventListener("change", updSubCount));
      updSubCount();
    };
    modSel.addEventListener("change", syncMod); syncMod();'''

OLD2 = r'''    .ta-subgrid{display:grid;grid-template-columns:repeat(2,1fr);gap:8px 16px;margin-top:9px}
    .ta-chk{display:flex;align-items:center;gap:8px;cursor:pointer;font-size:13px;color:#4b5462}
    .ta-chk input{accent-color:#2563eb}'''

NEW2 = r'''    .ta-subhead{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap} /* INVITE_SELALL_V1 */
    .ta-subtools{display:flex;align-items:center;gap:8px}
    .ta-subcount{font-size:11.5px;color:#8a93a2;font-variant-numeric:tabular-nums}
    .ta-chip{border:1px solid #d7dbe3;background:#fff;color:#2563eb;font-weight:650;font-size:11.5px;padding:5px 10px;border-radius:8px;cursor:pointer;transition:.12s}
    .ta-chip:hover{background:#eff4ff;border-color:#93b4f5}
    .ta-subgrid{display:grid;grid-template-columns:repeat(2,1fr);gap:7px 12px;margin-top:10px}
    .ta-chk{display:flex;align-items:center;gap:9px;cursor:pointer;font-size:13px;color:#4b5462;padding:8px 11px;border:1px solid #e6eaf0;border-radius:9px;background:#fff;transition:.12s;user-select:none}
    .ta-chk:hover{border-color:#c3ccd9;background:#fafbfd}
    .ta-chk input{accent-color:#2563eb;width:15px;height:15px;flex:none}
    .ta-chk:has(input:checked){border-color:#2563eb;background:#eff4ff;color:#12182a;font-weight:600}
    @media(max-width:520px){.ta-subgrid{grid-template-columns:1fr}}'''

for name, old in [("SYNCMOD", OLD1), ("CSS", OLD2)]:
    c = orig.count(old)
    assert c == 1, "ANCHOR %s bulundu=%d" % (name, c)

s = orig.replace(OLD1, NEW1).replace(OLD2, NEW2)
if not os.path.exists(path + ".invselallbak"):
    with io.open(path + ".invselallbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
