#!/usr/bin/env python3
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)
FP = "shells/saha.js"
s = read(FP)
if "PTR_FIX_V1" in s:
    print("ptr-fix: already present, skip"); print("DONE."); raise SystemExit
A = "  .saha-main{flex:1;min-width:0;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;padding:12px 12px calc(12px + env(safe-area-inset-bottom,0px))} /* EBATKART_TASMA_V2 */\n"
assert s.count(A) == 1, "saha-main CSS anchor (count!=1)"
N = A + (
    "  /* PTR_FIX_V1 — WebView pull-to-refresh KAPALI. */\n"
    "  html, body { overscroll-behavior: none; }\n"
    "  .saha-app, .saha-main, .modal-fon, .modal-kutu { overscroll-behavior-y: contain; }\n"
)
s = s.replace(A, N, 1)
write(FP, s)
print("ptr-fix OK, marker count:", s.count("PTR_FIX_V1"))
print("DONE.")
