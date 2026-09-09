#!/usr/bin/env python3
# HARITA_CHECKIN_V1 (client) — Harita'ya check-in noktalarini ayri yesil pin olarak ekle.
#   Musteri-marker dongusunden sonra /api/saha/harita-checkinler cek + her noktaya circleMarker + Yol Tarifi.
#   Cok-lokasyon firmalar (NUH BETON) artik her sahasi ayri pin. Idempotent (marker: HARITA_CHECKIN_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "HARITA_CHECKIN_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''          pts.push([lat, lng]);
        }
        try {
          const iller = [...new Set(musteriler.map(x => x.il).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b), "tr"));'''
new = '''          pts.push([lat, lng]);
        }
        try {  /* ''' + MARK + ''' — her check-in noktasi ayri yesil pin (~100m dedup) */
          const _cq = tip ? ("?tip=" + encodeURIComponent(tip)) : "";
          const _cr = await api("/api/saha/harita-checkinler" + _cq);
          for (const c of (_cr.noktalar || [])) {
            if (c.lat == null || c.lng == null) continue;
            const clat = Number(c.lat), clng = Number(c.lng); if (isNaN(clat) || isNaN(clng)) continue;
            const cm = L.circleMarker([clat, clng], { radius: 5, color: "#fff", weight: 1.5, fillColor: "#10b981", fillOpacity: 0.9 }).addTo(map);
            const _cy = [c.il, c.ilce].filter(Boolean).join(" / ");
            cm.bindPopup(`<div style="min-width:180px"><div style="font-size:13px;font-weight:700;margin-bottom:2px">📍 ${esc(c.firma || "")}</div><div style="font-size:11px;color:#64748b;margin-bottom:6px">Check-in noktası${Number(c.adet) > 1 ? " · " + c.adet + " ziyaret" : ""}${_cy ? " · " + esc(_cy) : ""}${c.son ? " · " + new Date(c.son).toLocaleDateString("tr-TR") : ""}</div><button class="cp-yol" style="padding:4px 10px;border:none;border-radius:6px;background:#0ea5e9;color:#fff;font-size:12px;cursor:pointer">Yol Tarifi</button></div>`);
            cm.on("popupopen", (e) => { const rt = e.popup.getElement(); const b = rt && rt.querySelector(".cp-yol"); if (b) b.onclick = () => { try { yolTarifi(clat, clng, c.firma); } catch (_) {} }; });
            pts.push([clat, clng]);
          }
        } catch (_) {}
        try {
          const iller = [...new Set(musteriler.map(x => x.il).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b), "tr"));'''
if old not in src:
    print("HATA: musteri marker dongusu sonu anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] check-in noktalari haritaya cizildi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
