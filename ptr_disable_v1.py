FP = "shells/saha.js"
s = open(FP, encoding="utf-8").read()
if "PTR_DISABLE_V1" in s:
    print("already present"); raise SystemExit
A = '  try {\n    if (!("ontouchstart" in window) && !(navigator.maxTouchPoints > 0)) return; // sadece dokunmatik\n'
assert s.count(A) == 1, "anchor bulunamadi"
N = '  try {\n    return; /* PTR_DISABLE_V1 — cek-yenile kapatildi (iPhone gibi) */\n    if (!("ontouchstart" in window) && !(navigator.maxTouchPoints > 0)) return; // sadece dokunmatik\n'
s = s.replace(A, N, 1)
open(FP, "w", encoding="utf-8").write(s)
print("ptr-disable OK, marker:", s.count("PTR_DISABLE_V1"))
