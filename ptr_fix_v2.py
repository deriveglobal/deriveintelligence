FP = "shells/saha.js"
s = open(FP, encoding="utf-8").read()
if "PTR_FIX_V2" in s:
    print("v2 already present"); raise SystemExit
A = "  .saha-app, .saha-main, .modal-fon, .modal-kutu { overscroll-behavior-y: contain; }\n"
assert s.count(A) == 1, "V1 satiri bulunamadi"
N = "  .saha-app, .saha-main, .modal-fon, .modal-kutu { overscroll-behavior-y: none; } /* PTR_FIX_V2 */\n"
s = s.replace(A, N, 1)
open(FP, "w", encoding="utf-8").write(s)
print("v2 OK, marker:", s.count("PTR_FIX_V2"))
