# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# NAV_MORE — bottom nav: 4 core tabs (Bugün/Ziyaretler/Teklif/Asistan) + "Daha"
# overflow sheet for the rest; hidden badges bubble onto Daha; active-tab highlight.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 5) dahaSheet() before layout()
rep("function layout() {",
    r'''function dahaSheet() {
  const items = (S.moreTabs || []).map(([id, ico, l]) => {
    const bdg = (S.moreBadges && S.moreBadges[id]) ? `<sup style="position:absolute;top:8px;right:14px;background:#ef4444;color:#fff;border-radius:9px;padding:0 5px;font-size:10px">${S.moreBadges[id]}</sup>` : "";
    return `<button class="daha-item" data-v="${id}" style="position:relative;display:flex;flex-direction:column;align-items:center;gap:5px;padding:16px 8px;border:1px solid #e2e8f0;border-radius:12px;background:#fff;cursor:pointer">${bdg}<span style="font-size:26px">${ico}</span><span style="font-size:12px;color:#334155;font-weight:600">${l}</span></button>`;
  }).join("");
  modal(`<h3 style="margin:0 0 12px">Daha Fazla</h3><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px">${items}</div><div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
  document.querySelectorAll(".daha-item").forEach(b => b.addEventListener("click", () => { kapatModal(); loadView(b.dataset.v); }));
}

function layout() {''',
    "daha-sheet")

# 1a) core/more split
rep('''    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"], ["sistem", "🔧", "Sistem"]] : [])
  ];
  return `''',
    '''    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"], ["sistem", "🔧", "Sistem"]] : [])
  ];
  const CORE = ["bugun","ziyaretler","iskonto","rep-brain"];
  S.coreIds = CORE;
  const coreTabs = tabs.filter(t => CORE.includes(t[0]));
  S.moreTabs = tabs.filter(t => !CORE.includes(t[0]));
  return `''',
    "core-split")

# 1b) nav render — core tabs + Daha
rep('''    <nav class="saha-nav">
      ${tabs.map(([id, ico, l]) => `<button class="saha-tab${id === "bugun" ? " on" : ""}" data-v="${id}"><span>${ico}</span>${l}</button>`).join("")}
    </nav>''',
    '''    <nav class="saha-nav">
      ${coreTabs.map(([id, ico, l]) => `<button class="saha-tab${id === "bugun" ? " on" : ""}" data-v="${id}"><span>${ico}</span>${l}</button>`).join("")}
      <button class="saha-tab" data-v="daha"><span>⋯</span>Daha</button>
    </nav>''',
    "nav-render")

# 2) wireNav — Daha opens the sheet
rep('''  S.container.querySelectorAll(".saha-tab").forEach(b =>
    b.addEventListener("click", () => {
      S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x === b));
      loadView(b.dataset.v);
    }));''',
    '''  S.container.querySelectorAll(".saha-tab").forEach(b =>
    b.addEventListener("click", () => {
      if (b.dataset.v === "daha") { dahaSheet(); return; }
      loadView(b.dataset.v);
    }));''',
    "wirenav")

# 3) loadView — highlight core tab or Daha
rep('''function loadView(v) {
  S.view = v;
  const m = main();''',
    '''function loadView(v) {
  S.view = v;
  const _navId = (S.coreIds || []).includes(v) ? v : "daha";
  S.container?.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === _navId));
  const m = main();''',
    "loadview-hl")

# 4) tabBadge — bubble hidden-tab badges onto Daha
rep('''function tabBadge(v, sayi) {
  const tab = S.container.querySelector(`.saha-tab[data-v="${v}"]`);
  if (!tab) return;''',
    '''function tabBadge(v, sayi) {
  S.moreBadges = S.moreBadges || {};
  const isCore = (S.coreIds || ["bugun","ziyaretler","iskonto","rep-brain"]).includes(v);
  if (!isCore) {
    if (sayi > 0) S.moreBadges[v] = sayi; else delete S.moreBadges[v];
    sayi = Object.values(S.moreBadges).reduce((a, b) => a + Number(b || 0), 0);
  }
  const tab = S.container.querySelector(`.saha-tab[data-v="${isCore ? v : "daha"}"]`);
  if (!tab) return;''',
    "tabbadge")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
