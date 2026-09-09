#!/usr/bin/env python3
# PUSH_PLATFORM_FIX — push token'i "android" olarak sabit kaydediliyordu; gerçek platformu
# (Capacitor.getPlatform() → ios/android) yaz. Böylece iOS token'ları APNs ile, Android FCM ile
# gönderilir. Sadece kayıt etiketi değişir; Android davranışı birebir aynı ("android").
# Idempotent. Run in /opt/krb-assessment.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
old = 'body: JSON.stringify({ token: tk.value, platform: "android" })'
new = 'body: JSON.stringify({ token: tk.value, platform: (C.getPlatform ? C.getPlatform() : "android") }) /* PUSH_PLATFORM_FIX */'
if "PUSH_PLATFORM_FIX" in s:
    print("saha.js: already patched, skip")
elif old in s:
    s = s.replace(old, new, 1)
    write(FP, s)
    print("saha.js: platform fix applied (ios/android)")
else:
    print("WARN: anchor not found — check saha.js push-register line")
print("DONE.")
