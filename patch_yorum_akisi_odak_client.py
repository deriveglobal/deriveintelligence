#!/usr/bin/env python3
# YORUM_AKISI_ODAK_V1 (client) — "Yorumlar" karti firehose'dan ODAK'a: satirlar artik
#   okunmamis yorum bildirimlerinden (bi_bildirim govde) render edilir. Boylece liste = rozet.
#   Her satir: 🚗/📢 + govde (yazan · firma/baslik: ozet) + zaman. Dokun → ziyaret/duyuru acilir
#   (mevcut global [data-zid]/[data-did] kablolamasi). Onkosul: YORUM_AKISI_V1 (client) CANLI.
#   Idempotent (marker: YORUM_AKISI_ODAK_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_AKISI_ODAK_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''    const yorumHtml = (_yorumAkisi.yorumlar || []).length === 0
      ? empty("Henüz yorum yok")
      : _yorumAkisi.yorumlar.map(y => {  /* YORUM_AKISI_V1 */
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
        }).join("");'''
new = '''    const yorumHtml = (_yorumAkisi.yorumlar || []).length === 0
      ? empty("Yeni yorum yok ✓")
      : _yorumAkisi.yorumlar.map(y => {  /* ''' + MARK + ''' — odak: okunmamis bildirim satirlari */
          const _duy = y.tur === "duyuru";
          const _nav = _duy ? `data-did="${y.ref_id}"` : `data-zid="${y.ref_id}"`;
          const _tag = _duy ? "📢" : "🚗";
          const _zaman = new Date(y.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
          return `
          <div class="kart" ${_nav} style="padding:10px 12px;margin-bottom:6px;cursor:pointer">
            <div class="kart-ust" style="align-items:flex-start">
              <span style="font-size:12px;color:#334155;line-height:1.35;white-space:pre-wrap;word-break:break-word">${_tag} ${esc(y.govde || "")}</span>
              <span style="font-size:11px;color:#94a3b8;white-space:nowrap;margin-left:8px">${_zaman}</span>
            </div>
          </div>`;
        }).join("");'''
if old not in src:
    print("HATA: YORUM_AKISI_V1 yorumHtml anchor bulunamadi (V1 client canli mi?)"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] yorumHtml → odak (govde satirlari)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
