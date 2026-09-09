# -*- coding: utf-8 -*-
# KAPSAM_DK_TEMA_V1 — Kapsam sekmesi koyu-tema düzeltmesi (SAHA_TEMA_FIX2 dersi):
#   .kap sarmalayıcısına UYGULAMANIN GERÇEK token adlarını (--zemin-*, --tx-*, --cizgi...)
#   açık değerlerle yeniden bildir → global td/th/table kuralları açık çözülür.
#   + tablo hücrelerine açık arka planı AÇIKÇA sabitle (çift güvence).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_DK_TEMA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "KAPSAM_DK_V1" in s, "once KAPSAM_DK_V1 olmali"

# 1) .kap içine uygulamanın gerçek token adlarını (açık) ekle
o1 = '.kap{--z0:#FBFBFA;'
n1 = ('.kap{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--cizgi-g:rgba(0,0,0,.18);'
      '--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--kirmizi-p:#C43D28;'
      '--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--yesil-p:#106B4A;--mavi:#2563eb;'
      '/*KAPSAM_DK_TEMA_V1*/--z0:#FBFBFA;')
assert s.count(o1) == 1, "kap token anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) tablo/başlık/hücre arka planlarını açıkça sabitle
o2 = '.kap table{width:100%;border-collapse:collapse}'
n2 = '.kap table{width:100%;border-collapse:collapse;background:var(--z1)}'
assert s.count(o2) == 1, "table anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

o3 = '.kap th{font-size:9.5px;text-transform:uppercase;letter-spacing:.04em;color:var(--t2);font-weight:700;text-align:left;padding:0 8px 8px}'
n3 = '.kap th{font-size:9.5px;text-transform:uppercase;letter-spacing:.04em;color:var(--t2);font-weight:700;text-align:left;padding:0 8px 8px;background:var(--z1)}'
assert s.count(o3) == 1, "th anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

o4 = '.kap td{padding:9px 8px;border-top:1px solid var(--cz);font-size:12.5px;vertical-align:middle}'
n4 = '.kap td{padding:9px 8px;border-top:1px solid var(--cz);font-size:12.5px;vertical-align:middle;background:var(--z1)}'
assert s.count(o4) == 1, "td anchor=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

# ayrıca thead/tbody/tr açık zemin (global koyu kural için)
o5 = '.kap-num{color:var(--t3);font-weight:700;width:26px}'
n5 = '.kap-num{color:var(--t3);font-weight:700;width:26px}\n      .kap thead,.kap tbody,.kap tr{background:var(--z1)}  /*KAPSAM_DK_TEMA_V1*/'
assert s.count(o5) == 1, "num anchor=%d" % s.count(o5)
s = s.replace(o5, n5, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_DK_TEMA_V1 (saha_desktop.js)")
