FP = "shells/saha.js"
s = open(FP, encoding="utf-8").read()
if "SAHA_YENILE_V1" in s:
    print("already present"); raise SystemExit
A1 = '<button id="saha-cikis"'
assert s.count(A1) == 1, "cikis anchor"
BTN = '<button id="saha-yenile" title="Yenile" style="background:none;border:none;color:#94a3b8;font-size:17px;cursor:pointer;padding:0 4px;line-height:1">⟳</button>'
s = s.replace(A1, BTN + A1, 1)
A2 = '  S.container.querySelector("#saha-home")?.addEventListener("click", () => setRoom("reception"));\n'
assert s.count(A2) == 1, "home anchor"
H = (
    '  S.container.querySelector("#saha-yenile")?.addEventListener("click", () => { /* SAHA_YENILE_V1 */\n'
    '    const yb = S.container.querySelector("#saha-yenile");\n'
    '    if (yb) { yb.style.transition = "transform .5s"; yb.style.transform = "rotate(360deg)"; setTimeout(() => { yb.style.transition = ""; yb.style.transform = ""; }, 520); }\n'
    '    const rb = S.container.querySelector(".saha-roombar");\n'
    '    if (rb && getComputedStyle(rb).display !== "none") { const o = rb.querySelector(".saha-rtab.on"); if (o) { o.click(); return; } }\n'
    '    const t = S.container.querySelector(".saha-nav .saha-tab.on");\n'
    '    if (t && t.dataset.v !== "daha") { loadView(t.dataset.v); return; }\n'
    '    if (S.view) loadView(S.view);\n'
    '  });\n'
)
s = s.replace(A2, A2 + H, 1)
open(FP, "w", encoding="utf-8").write(s)
print("saha-yenile OK, marker:", s.count("SAHA_YENILE_V1"))
