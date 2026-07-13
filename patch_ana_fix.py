#!/usr/bin/env python3
"""ANA_UI_FIX — iki hata, ikisi de benim.

⚠ HATA 1: Eski 'home' odasi createElement ile kuruluyor ve GIZLE SINIFI ALMIYOR
   (_hr.className = 'vmo-room'). Varsayilan oda o oldugu icin sorun cikmiyordu.
   activeDept'i 'bugun' yapinca home HALA GORUNUR kaldi -> canvas ustu kapatti.

⚠ HATA 2: Kendi odama display:block SATIR ICI stil verdim.
   Satir ici stil, .vmo-room-hidden{display:none} kuralini EZER.
   Yani odam GIZLENEMEZ hale gelmis — baska odaya gecince de gorunmeye devam eder.
   Satir ici display KALDIRILIYOR; gorunurlugu SINIF sistemi yonetsin.

✅ COZUM: mevcut mekanizmayi kullan, yenisini yazma.
   Satir 1072 zaten dogru: r.classList.toggle('vmo-room-hidden', r.dataset.dept !== activeDept)
   Sadece ACILISTA bir kez calistir.
"""
import re, sys, pathlib

p = pathlib.Path("shells/bi.js")
src = p.read_text(encoding="utf-8")
if "ANA_UI_FIX" in src:
    sys.exit("ZATEN YAMALI")

n = 0

# ── FIX 1: kendi odamdan satir ici display:block'u KALDIR ────────────────────
eski = "_br.style.cssText = 'background:var(--zemin-0);overflow-y:auto;display:block;padding:0';"
if eski not in src:
    sys.exit("❌ anchor yok: _br.style.cssText")
yeni = "_br.style.cssText = 'background:var(--zemin-0);overflow-y:auto;padding:0';  /* ANA_UI_FIX: display satir ici OLMAZ — .vmo-room-hidden'i ezer */"
src = src.replace(eski, yeni, 1); n += 1
print("  ✅ FIX 1: satir ici display kaldirildi")

# ── FIX 2: acilista TUM odalari senkronla (eski home dahil) ──────────────────
eski2 = "  ciz_bugun();"
if eski2 not in src:
    sys.exit("❌ anchor yok: ciz_bugun() cagrisi")
yeni2 = r'''  // ⚠ ANA_UI_FIX — ACILIS SENKRONU
  // Eski 'home' odasi createElement ile kuruluyor ve gizle sinifi ALMIYOR.
  // OFFICERS.map ile uretilenler aliyor, sonradan eklenenler ALMIYOR.
  // Mevcut mekanizmayi (satir ~1072) acilista BIR KEZ calistir.
  setTimeout(function(){
    container.querySelectorAll('.vmo-room').forEach(function(r){
      r.classList.toggle('vmo-room-hidden', r.dataset.dept !== activeDept);
    });
    container.querySelectorAll('.vmo-tab').forEach(function(t){
      t.classList.toggle('active', t.dataset.dept === activeDept);
    });
  }, 0);

  ciz_bugun();'''
src = src.replace(eski2, yeni2, 1); n += 1
print("  ✅ FIX 2: acilis senkronu (eski home artik gizleniyor)")

# ── FIX 3: gizleme kurali satir ici stillere karsi GARANTILI olsun ───────────
eski3 = "  .vmo-room-hidden { display:none; }"
if eski3 in src:
    src = src.replace(eski3, "  .vmo-room-hidden { display:none !important; }  /* ANA_UI_FIX */", 1); n += 1
    print("  ✅ FIX 3: .vmo-room-hidden !important")
else:
    print("  ⚠ FIX 3 atlandi (kural bulunamadi) — FIX 1 zaten yeterli")

p.write_text(src, encoding="utf-8")
print(f"\n  {n} duzeltme.")
