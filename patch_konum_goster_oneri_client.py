#!/usr/bin/env python3
# ZIYARET_KONUM_GOSTER_V1 + ONERI_TEXTAREA_AUTOGROW_V1 (client) — DÜZELTİLMİŞ (create _zfBody degisikligi YOK;
#   pini zaten create-sonrasi checkin PUT gonderiyor). Bu yama yalniz:
#   (1) Ziyaret detayinda checkin_lat/lng varsa "Pinlenen konum → Haritada ac" satiri (pin GORUNUR olsun).
#   (2) Oneri kutusu textarea (#on-mesaj) autogrow — "yazdikca kaymiyor".
#   Idempotent (markerlar: ZIYARET_KONUM_GOSTER_V1 / ONERI_TEXTAREA_AUTOGROW_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
if "ZIYARET_KONUM_GOSTER_V1" in src and "ONERI_TEXTAREA_AUTOGROW_V1" in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) ziyaret detay: pinlenen konum satiri
old1 = '''    ${satir("Konum", [z.il, z.ilce].filter(Boolean).join(" / "))}
    ${z.checkin_at ? satir("Check-in", new Date(z.checkin_at).toLocaleString("tr-TR")) : ""}'''
new1 = '''    ${satir("Konum", [z.il, z.ilce].filter(Boolean).join(" / "))}
    ${(z.checkin_lat != null && z.checkin_lng != null) ? `<div class="det-satir"><span>Pinlenen konum</span><b><a href="https://www.google.com/maps?q=${z.checkin_lat},${z.checkin_lng}" target="_blank" rel="noopener" style="color:#0ea5e9;text-decoration:none">📍 Haritada aç</a></b></div>` : ""}  <!-- ZIYARET_KONUM_GOSTER_V1 -->
    ${z.checkin_at ? satir("Check-in", new Date(z.checkin_at).toLocaleString("tr-TR")) : ""}'''
if old1 not in src:
    print("HATA: ziyaret detay Konum anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)
print("[+] ziyaret detay: pinlenen konum satiri")

# 2) oneri textarea autogrow
old2 = '''    ${gecmisHtml}
  `);

  document.querySelectorAll("[data-goid]").forEach(el => el.addEventListener("click", () => {'''
new2 = '''    ${gecmisHtml}
  `);

  { const _om = document.getElementById("on-mesaj"); if (_om) { const _g = () => { _om.style.height = "auto"; _om.style.height = Math.min(_om.scrollHeight, 240) + "px"; }; _om.addEventListener("input", _g); setTimeout(_g, 0); } }  /* ONERI_TEXTAREA_AUTOGROW_V1 */

  document.querySelectorAll("[data-goid]").forEach(el => el.addEventListener("click", () => {'''
if old2 not in src:
    print("HATA: oneriModal anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] oneri textarea autogrow")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
