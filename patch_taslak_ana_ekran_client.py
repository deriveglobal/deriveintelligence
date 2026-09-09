#!/usr/bin/env python3
# TASLAK_ANA_EKRAN_V1 (client) — Ali Kemal: taslaga giden aktiviteye ulasmak icin tekrar giris uzun;
#   ana ekranda taslak aktivite karti olmali, oradan devam edilmeli.
#   FIX: (a) taslaga mus_id/firma/tip/mod ekle; (b) ziyaretFormModal'a autoTaslak param (ana ekrandan
#   gelince banner yerine otomatik geri-yukle); (c) Bugun ekranina "💾 Taslak aktivite" bolumu (localStorage
#   tarar) + dokun→devam.
#   Idempotent (marker: TASLAK_ANA_EKRAN_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "TASLAK_ANA_EKRAN_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# A) _tasTopla: mus bilgisini taslaga ekle
oldA = '''    const o = { ts: Date.now(), alan: {}, cip: {}, foto: fotolar.slice(), konum: { lat: konum.lat, lng: konum.lng } };'''
newA = '''    const o = { ts: Date.now(), alan: {}, cip: {}, foto: fotolar.slice(), konum: { lat: konum.lat, lng: konum.lng }, mus_id: mus.id, firma: mus.firma || mus.ad || "Müşteri", tip: tip, mod: mod };  /* ''' + MARK + ''' */'''
if oldA not in src:
    print("HATA: _tasTopla anchor bulunamadi"); sys.exit(1)
src = src.replace(oldA, newA, 1)
print("[+] A: taslaga mus bilgisi")

# B) ziyaretFormModal imza: autoTaslak
oldB = '''async function ziyaretFormModal(mus, mod, presetDate = null) {'''
newB = '''async function ziyaretFormModal(mus, mod, presetDate = null, autoTaslak = false) {  /* ''' + MARK + ''' */'''
if oldB not in src:
    print("HATA: ziyaretFormModal imza anchor bulunamadi"); sys.exit(1)
src = src.replace(oldB, newB, 1)
print("[+] B: autoTaslak param")

# C) taslak IIFE: autoTaslak ise otomatik geri-yukle
oldC = '''    if (Date.now() - d.ts > 7 * 86400000) { _tasSil(); return; }
    _tasHazir = false;  // kullanici karar verene kadar ustune yazma'''
newC = '''    if (Date.now() - d.ts > 7 * 86400000) { _tasSil(); return; }
    _tasHazir = false;  // kullanici karar verene kadar ustune yazma
    if (autoTaslak) { _tasYukle(d); _tasHazir = true; return; }  /* ''' + MARK + ''' — ana ekrandan gelince otomatik geri-yukle */'''
if oldC not in src:
    print("HATA: taslak IIFE anchor bulunamadi"); sys.exit(1)
src = src.replace(oldC, newC, 1)
print("[+] C: autoTaslak otomatik geri-yukle")

# D1) Bugun render: taslak container
oldD1 = '''        <div id="nabiz-hikaye"></div>'''
newD1 = '''        <div id="nabiz-hikaye"></div>
        <div id="bugun-taslaklar"></div>  <!-- ''' + MARK + ''' -->'''
if oldD1 not in src:
    print("HATA: nabiz-hikaye anchor bulunamadi"); sys.exit(1)
src = src.replace(oldD1, newD1, 1)
print("[+] D1: taslak container")

# D2) Bugun: taslak kartlarini doldur
oldD2 = '''    baslangicStripYukle();
    nabizHikayeYukle(); /* NABIZ_HIKAYE_V2 */'''
newD2 = '''    baslangicStripYukle();
    nabizHikayeYukle(); /* NABIZ_HIKAYE_V2 */
    (function _taslakKartlari() {  /* ''' + MARK + ''' — kaydedilmis ziyaret taslaklarini ana ekranda goster */
      try {
        const box = document.getElementById("bugun-taslaklar"); if (!box) return;
        const list = [];
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i); if (!k || k.indexOf("saha-ziy-taslak-") !== 0) continue;
          let d = null; try { d = JSON.parse(localStorage.getItem(k)); } catch (e) { continue; }
          if (!d || !d.ts || (Date.now() - d.ts > 7 * 86400000) || !d.mus_id) continue;
          list.push({ key: k, mus_id: d.mus_id, firma: d.firma || "Müşteri", tip: d.tip || "TUKETICI", mod: d.mod || "kaydet", ts: d.ts });
        }
        if (!list.length) { box.innerHTML = ""; return; }
        list.sort((a, b) => b.ts - a.ts);
        const rows = list.map(t => {
          const dk = Math.max(1, Math.round((Date.now() - t.ts) / 60000));
          const ne = dk < 60 ? (dk + " dk") : (dk < 1440 ? (Math.round(dk / 60) + " saat") : (Math.round(dk / 1440) + " gün"));
          return `<div class="kart" data-taslak="${esc(t.key)}" style="padding:10px 12px;margin-bottom:6px;cursor:pointer;border-left:3px solid #10b981">
            <div class="kart-ust"><b style="font-size:13px">💾 ${esc(t.firma)}</b><span style="font-size:11px;color:#94a3b8;white-space:nowrap;margin-left:6px">${ne} önce</span></div>
            <div style="font-size:11px;color:#059669;margin-top:2px">Yarım kalan ${t.mod === "planla" ? "plan" : "ziyaret"} — devam et ▶</div>
          </div>`;
        }).join("");
        box.innerHTML = `<div style="margin:14px 0 6px"><div style="font-size:11px;font-weight:700;color:#374151;padding-left:10px;border-left:3px solid #10b981;text-transform:uppercase;letter-spacing:.5px">💾 Taslak aktivite (${list.length})</div></div>` + rows;
        box.querySelectorAll("[data-taslak]").forEach(el => el.addEventListener("click", () => {
          const t = list.find(x => x.key === el.dataset.taslak); if (!t || !t.mus_id) return;
          ziyaretFormModal({ id: t.mus_id, firma: t.firma, tip: t.tip }, t.mod, null, true);
        }));
      } catch (e) {}
    })();'''
if oldD2 not in src:
    print("HATA: baslangicStripYukle anchor bulunamadi"); sys.exit(1)
src = src.replace(oldD2, newD2, 1)
print("[+] D2: taslak kartlari (Bugun)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
