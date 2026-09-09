#!/usr/bin/env python3
# YORUM_GORULDU_V1 (client) — ziyaret yorumunun altina "✓ görüldü" (server y.goruldu bayragi).
#   Yorumu yazan, ilgili kisi ziyareti gorunce landing'i dogrudan gorsun. Idempotent (marker).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_GORULDU_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) marker (idempotent + izlenebilir)
old1 = '''  function renderYorumlar(yorumlar) {'''
new1 = '''  function renderYorumlar(yorumlar) {  /* ''' + MARK + ''' */'''
if old1 not in src:
    print("HATA: renderYorumlar anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)

# 2) yorum balonunun altina goruldu satiri
old2 = '''          <div style="background:${yonetici ? "#f0f9ff" : "#f8fafc"};border:1px solid ${yonetici ? "#bae6fd" : "#e2e8f0"};border-radius:8px;padding:8px 10px;font-size:13px;color:#0f172a;white-space:pre-wrap;border-top-left-radius:2px">${esc(y.icerik)}</div>
        </div>`;'''
new2 = '''          <div style="background:${yonetici ? "#f0f9ff" : "#f8fafc"};border:1px solid ${yonetici ? "#bae6fd" : "#e2e8f0"};border-radius:8px;padding:8px 10px;font-size:13px;color:#0f172a;white-space:pre-wrap;border-top-left-radius:2px">${esc(y.icerik)}</div>
          ${y.goruldu ? `<span style="font-size:10px;color:#16a34a;font-weight:600;margin-left:2px">✓ görüldü</span>` : ""}
        </div>`;'''
if old2 not in src:
    print("HATA: yorum balonu anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] '✓ görüldü' yorum altina eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
