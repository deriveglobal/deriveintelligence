#!/usr/bin/env python3
# YORUM_AKISI_V1 (client) — Bugun ekranina "🗨️ Yorumlar" karti (Mesajlar altina), BIRLESIK akis.
#   Satir tur'e gore: ziyaret → data-zid (ziyaret acilir, 🚗), duyuru → data-did (duyuru acilir, 📢).
#   baslik = firma/duyuru basligi; ✓ görüldü yalniz ziyaret yorumunda. Idempotent (marker: YORUM_AKISI_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_AKISI_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) bugun destructure sonrasi yorum-akisi cek
old1 = '''    const { bugun, ziyaretler, duyurular_okunmamis, duyurular_yeni_sayisi = 0, rep_sayisi = 0, mesaj_okunmamis, teklifler, hatirlatmalar } = await api("/api/saha/bugun");'''
new1 = old1 + '''
    let _yorumAkisi = { yorumlar: [], okunmamis: 0 };  /* ''' + MARK + ''' */
    try { _yorumAkisi = await api("/api/saha/yorum-akisi"); } catch (e) {}'''
if old1 not in src:
    print("HATA: bugun destructure anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)
print("[+] yorum-akisi fetch eklendi")

# 2) yorumHtml (birlesik) — main().innerHTML oncesi
old2 = '''    main().innerHTML = `
      <div style="padding:2px 0 24px">'''
new2 = '''    const yorumHtml = (_yorumAkisi.yorumlar || []).length === 0
      ? empty("Henüz yorum yok")
      : _yorumAkisi.yorumlar.map(y => {  /* ''' + MARK + ''' */
          const _duy = y.tur === "duyuru";
          const _nav = _duy ? `data-did="${y.ref_id}"` : `data-zid="${y.ref_id}"`;
          const _tag = _duy ? "📢" : "🚗";
          const _bas = esc(y.baslik || (_duy ? "Duyuru" : "Ziyaret"));
          const _zaman = new Date(y.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
          return `
          <div class="kart" ${_nav} style="padding:10px 12px;margin-bottom:6px;cursor:pointer">
            <div class="kart-ust"><b style="font-size:13px">${_tag} ${_bas}</b><span style="font-size:11px;color:#94a3b8">${_zaman}</span></div>
            <div style="font-size:12px;color:#334155;margin-top:3px;white-space:pre-wrap;word-break:break-word"><b>${esc(y.user_adi)}:</b> ${esc(y.icerik)}</div>
            ${y.goruldu ? `<div style="font-size:10px;color:#16a34a;margin-top:2px">✓ görüldü</div>` : ""}
          </div>`;
        }).join("");
    main().innerHTML = `
      <div style="padding:2px 0 24px">'''
if old2 not in src:
    print("HATA: main().innerHTML anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] yorumHtml (birlesik) eklendi")

# 3) secBlock Yorumlar (Mesajlar altina)
old3 = '''        ${secBlock("💬", "Mesajlar", mesaj_okunmamis || null, "#0284c7", mesajHtml, { kapali: true })}'''
new3 = old3 + '''
        ${secBlock("🗨️", "Yorumlar", _yorumAkisi.okunmamis || null, "#0284c7", yorumHtml, { kapali: true })}  <!-- ''' + MARK + ''' -->'''
if old3 not in src:
    print("HATA: Mesajlar secBlock anchor bulunamadi"); sys.exit(1)
src = src.replace(old3, new3, 1)
print("[+] Yorumlar karti eklendi (Mesajlar altina)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
