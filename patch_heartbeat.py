import sys
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "REP_AKTIVITE_HB" in s: print("[skip] zaten var"); sys.exit(0)
ANCHOR='  injectStyles();\n  container.innerHTML = layout();\n  wireNav();'
assert s.count(ANCHOR)==1, "anchor sorunu: %d"%s.count(ANCHOR)
ADD=ANCHOR+r'''
  try { /* REP_AKTIVITE_HB — kalp atisi: uygulama acikken her 60sn mevcut ekrani bildir */
    if (window.__sahaHB) clearInterval(window.__sahaHB);
    const _sahaPing = function () {
      if (typeof document !== "undefined" && document.visibilityState && document.visibilityState !== "visible") return;
      try { api("/api/saha/aktivite-ping", { method: "POST", body: JSON.stringify({ oda: (S && (S.view || S.room)) || "", platform: "app" }) }).catch(function () {}); } catch (e) {}
    };
    _sahaPing();
    window.__sahaHB = setInterval(_sahaPing, 60000);
    if (typeof document !== "undefined") document.addEventListener("visibilitychange", function () { if (document.visibilityState === "visible") _sahaPing(); });
  } catch (e) {}'''
s=s.replace(ANCHOR, ADD, 1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] REP_AKTIVITE_HB (heartbeat) eklendi")
