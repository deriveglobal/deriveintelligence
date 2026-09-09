#!/usr/bin/env python3
# PULL_REFRESH_OFF_V1 (client) — Fatih 04.08: pull-to-refresh tamamen kapatilsin. Uygulamanin kendi
#   PULL_REFRESH_V1 handler'i (yukari cek-birak → "⟳ Yenileniyor…") yalniz dikey dy'ye bakiyor ama
#   yatay/capraz kaydirmayi ayirt etmiyordu → sagdan-sola swipe kazara "Yenileniyor" tetikliyordu.
#   Karar: ozelligi tamamen kapat. Fix: IIFE'nin basina erken `return` koy — hicbir touch listener
#   baglanmaz, pill hic olusmaz. Kod silinmez (geri alinabilir). Idempotent (marker: PULL_REFRESH_OFF_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "PULL_REFRESH_OFF_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''(function () {
  try {
    if (!("ontouchstart" in window) && !(navigator.maxTouchPoints > 0)) return; // sadece dokunmatik
    if (window.__sahaPTR) return;'''
new = '''(function () {
  try {
    return; /* ''' + MARK + ''' — pull/swipe-to-refresh TAMAMEN KAPALI (Fatih 04.08: yan-swipe kazara tetikliyordu) */
    if (!("ontouchstart" in window) && !(navigator.maxTouchPoints > 0)) return; // sadece dokunmatik
    if (window.__sahaPTR) return;'''
if old not in src:
    print("HATA: PULL_REFRESH_V1 IIFE anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] PULL_REFRESH_V1 devre disi (erken return)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
