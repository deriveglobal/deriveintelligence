#!/usr/bin/env python3
# RAPOR_ARALIK_PRESET_V1 (client) — Rapor tarih aralığına hazir kisayollar.
#   Yildiray: Bu ay / Gecen ay / Bu yil. Fatih: 3/6/9/12 ay + YTD(=Bu yil).
#   Mevcut gun-bazli satir 7G/30G/3A/1Y -> 7G/30G/3A/6A/9A/12A (rolling).
#   Yeni takvim satiri: Bu ay (ay basi->bugun), Gecen ay (onceki tam ay), Bu yil (1 Ocak->bugun, =YTD).
#   Takvim tarihleri Istanbul-yerel hesaplanir (en-CA), UTC kaymasi yok. Server degismez (from/to zaten var).
#   Idempotent (marker: RAPOR_ARALIK_PRESET_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "RAPOR_ARALIK_PRESET_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# --- 1) Render: gun-bazli satiri genislet + takvim satiri ekle ---
old1 = '''        <div style="display:flex;gap:5px;margin-bottom:6px">
        ${[["7G",7],["30G",30],["3A",90],["1Y",365]].map(([l,d]) =>
          `<button class="rp-preset" data-days="${d}" style="flex:1;padding:5px 0;border:1px solid #e5e7eb;border-radius:6px;background:#fff;font-size:12px;font-weight:500;color:#374151;cursor:pointer">${l}</button>`
        ).join("")}
      </div>'''
new1 = '''        <div style="display:flex;gap:5px;margin-bottom:5px"><!--''' + MARK + ''' rolling-->
        ${[["7G",7],["30G",30],["3A",90],["6A",180],["9A",270],["12A",365]].map(([l,d]) =>
          `<button class="rp-preset" data-days="${d}" style="flex:1;padding:5px 0;border:1px solid #e5e7eb;border-radius:6px;background:#fff;font-size:12px;font-weight:500;color:#374151;cursor:pointer">${l}</button>`
        ).join("")}
      </div>
      <div style="display:flex;gap:5px;margin-bottom:6px"><!--''' + MARK + ''' takvim-->
        ${[["Bu ay","buAy"],["Geçen ay","gecenAy"],["Bu yıl","buYil"]].map(([l,k]) =>
          `<button class="rp-cal" data-cal="${k}" style="flex:1;padding:5px 0;border:1px solid #e5e7eb;border-radius:6px;background:#fff;font-size:12px;font-weight:500;color:#374151;cursor:pointer">${l}</button>`
        ).join("")}
      </div>'''
if old1 not in src:
    print("HATA: preset render anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)
print("[+] preset satirlari (rolling 6 + takvim 3) render edildi")

# --- 2) rpMark: her cagrida takvim butonlarini da temizle ---
old2 = '''  const rpMark = (days) => { main().querySelectorAll(".rp-preset").forEach(b => { const on = Number(b.dataset.days) === days; b.style.background = on ? "#3b82f6" : "#fff"; b.style.color = on ? "#fff" : "#374151"; b.style.borderColor = on ? "#3b82f6" : "#e5e7eb"; b.style.fontWeight = on ? "700" : "500"; }); };  /* RAPOR_DEF30_V1 */'''
new2 = '''  const rpMark = (days) => { main().querySelectorAll(".rp-preset").forEach(b => { const on = Number(b.dataset.days) === days; b.style.background = on ? "#3b82f6" : "#fff"; b.style.color = on ? "#fff" : "#374151"; b.style.borderColor = on ? "#3b82f6" : "#e5e7eb"; b.style.fontWeight = on ? "700" : "500"; }); main().querySelectorAll(".rp-cal").forEach(b => { b.style.background = "#fff"; b.style.color = "#374151"; b.style.borderColor = "#e5e7eb"; b.style.fontWeight = "500"; }); };  /* RAPOR_DEF30_V1 */ /* ''' + MARK + ''' */'''
if old2 not in src:
    print("HATA: rpMark anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] rpMark takvim temizleme eklendi")

# --- 3) Takvim handler + rpMarkCal (rpMark(30) oncesi) ---
old3 = '''  rpMark(30);'''
new3 = '''  const rpMarkCal = (key) => {  /* ''' + MARK + ''' */
    main().querySelectorAll(".rp-preset").forEach(b => { b.style.background = "#fff"; b.style.color = "#374151"; b.style.borderColor = "#e5e7eb"; b.style.fontWeight = "500"; });
    main().querySelectorAll(".rp-cal").forEach(b => { const on = b.dataset.cal === key; b.style.background = on ? "#3b82f6" : "#fff"; b.style.color = on ? "#fff" : "#374151"; b.style.borderColor = on ? "#3b82f6" : "#e5e7eb"; b.style.fontWeight = on ? "700" : "500"; });
  };
  main().querySelectorAll(".rp-cal").forEach(btn => {  /* ''' + MARK + ''' — takvim bazli aralik */
    btn.addEventListener("click", () => {
      const key = btn.dataset.cal;
      const _ist = new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
      const [_iy, _im] = _ist.split("-").map(Number);
      const _fmt = (y, m, d) => y + "-" + String(m).padStart(2, "0") + "-" + String(d).padStart(2, "0");
      let f, t;
      if (key === "buAy")       { f = _fmt(_iy, _im, 1); t = _ist; }
      else if (key === "buYil") { f = _fmt(_iy, 1, 1);   t = _ist; }
      else { let py = _iy, pm = _im - 1; if (pm === 0) { pm = 12; py--; } f = _fmt(py, pm, 1); t = _fmt(py, pm, new Date(py, pm, 0).getDate()); }
      const fEl = document.getElementById("rp-from"), tEl = document.getElementById("rp-to");
      if (fEl) fEl.value = f; if (tEl) tEl.value = t;
      rpMarkCal(key);
      if (activeTab === "harita") { try { if (window._haritaDonemHook) window._haritaDonemHook(); } catch (_) {} } else { loadTab(activeTab); }
    });
  });
  rpMark(30);'''
if old3 not in src:
    print("HATA: rpMark(30) anchor bulunamadi"); sys.exit(1)
src = src.replace(old3, new3, 1)
print("[+] takvim handler + rpMarkCal eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
