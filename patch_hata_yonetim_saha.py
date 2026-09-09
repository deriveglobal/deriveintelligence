import sys
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "HATA_YONETIM_V1" in s: print("[skip] zaten var"); sys.exit(0)
A1='    ...(S.isOwner ? [["sistem", "\U0001F527", "Sistem"]] : [])'
assert s.count(A1)==1, "saha A1: %d"%s.count(A1)
s=s.replace(A1, '    ...((S.isOwner || S.isYonetim) ? [["sistem", "\U0001F527", "Sistem"]] : []) /* HATA_YONETIM_V1 */', 1)
A2='  if (!S.isOwner) {'
assert s.count(A2)==1, "saha A2: %d"%s.count(A2)
s=s.replace(A2, '  if (!S.isOwner && !S.isYonetim) { /* HATA_YONETIM_V1 */', 1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] HATA_YONETIM_V1 saha.js (Sistem sekmesi + vSistem yonetim'e acildi)")
