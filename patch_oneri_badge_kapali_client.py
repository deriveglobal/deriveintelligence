#!/usr/bin/env python3
# ONERI_BADGE_KAPALI_V1 (client) — Fatih istegi: bir kayit "Tamamlandi" olduktan sonra sorumlu kisi
#   cevap yazarsa yalniz e-posta ile fark ediliyor; uygulama icinde rozet yok.
#   Sebep: oneri nav rozeti (Daha sekmesi) yalniz durum YENI/INCELENIYOR olan okunmamis kayitlari
#   sayiyordu (ONERI_BADGE_FIX). TAMAMLANDI/REDDEDILDI'de yeni mesaj gelse bile rozet yanmiyordu.
#   Not: kart-ici kirmizi gostergesi (🔴 + kenar) zaten TUM durumlarda calisiyor; eksik olan sayac/rozetti.
#   Fix: rozet filtresinden durum kisitini kaldir → o.okunmamis olan HER kayit sayilir (kapali dahil).
#     Kayit acilinca okundu_at guncellenir → rozet duser (kalici nag yok).
#   2 yerde ayni satir (bugun yukleme + vOneriler). Idempotent (marker: ONERI_BADGE_KAPALI_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "ONERI_BADGE_KAPALI_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = 'tabBadge("oneriler", oneriler.filter(o => o.okunmamis && ["YENI", "INCELENIYOR"].includes(o.durum)).length); /* ONERI_BADGE_FIX */'
new = 'tabBadge("oneriler", oneriler.filter(o => o.okunmamis).length); /* ' + MARK + ' — kapali kayitta da yeni mesaj rozeti (Fatih istegi) */'

cnt = src.count(old)
if cnt == 0:
    print("HATA: ONERI_BADGE_FIX anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new)
print("[+] Rozet filtresi guncellendi (%d yer): kapali kayitlar da sayiliyor" % cnt)

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
