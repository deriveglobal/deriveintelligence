#!/usr/bin/env python3
# RAPOR_ARALIK_PRESET_DK_V1 (desktop) — Masaustu saha kabugu (shells/saha_desktop.js) rapor tarih
#   araligina hazir kisayollar (mobil RAPOR_ARALIK_PRESET_V1 ile parite).
#   Rolling: 7 gün/30 gün/3 ay/6 ay/9 ay/12 ay. Takvim: Bu ay / Geçen ay / Bu yıl (=YTD).
#   Takvim tarihleri Istanbul-yerel (en-CA). CSS-class tabanli (.rp-preset/.rp-cal .on). Server degismez.
#   Idempotent (marker: RAPOR_ARALIK_PRESET_DK_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "RAPOR_ARALIK_PRESET_DK_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) CSS: .rp-cal stilleri + iki satir icin flex-wrap
oldc = '''.rp-presets{display:flex;gap:6px}
.rp-preset{padding:6px 13px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);border-radius:8px;font-size:12.5px;font-weight:600;cursor:pointer}
.rp-preset:hover{border-color:var(--mavi);color:var(--mavi-koyu)}
.rp-preset.on{background:var(--mavi);color:#fff;border-color:var(--mavi)}'''
newc = '''.rp-presets{display:flex;gap:6px;flex-wrap:wrap}
.rp-preset,.rp-cal{padding:6px 13px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);border-radius:8px;font-size:12.5px;font-weight:600;cursor:pointer}
.rp-preset:hover,.rp-cal:hover{border-color:var(--mavi);color:var(--mavi-koyu)}
.rp-preset.on,.rp-cal.on{background:var(--mavi);color:#fff;border-color:var(--mavi)} /* ''' + MARK + ''' */'''
if oldc not in src:
    print("HATA: CSS anchor bulunamadi (canli saha_desktop.js cekildi mi?)"); sys.exit(1)
src = src.replace(oldc, newc, 1)
print("[+] CSS .rp-cal eklendi")

# 2) RENDER: rolling 6 + takvim satiri
oldr = '''      <div class="rp-presets">
        ${[["7 gün", 7], ["30 gün", 30], ["3 ay", 90], ["1 yıl", 365]].map(([l, d]) =>
    `<button class="rp-preset" data-days="${d}">${l}</button>`).join("")}
      </div>'''
newr = '''      <div class="rp-presets"><!--''' + MARK + ''' rolling-->
        ${[["7 gün", 7], ["30 gün", 30], ["3 ay", 90], ["6 ay", 180], ["9 ay", 270], ["12 ay", 365]].map(([l, d]) =>
    `<button class="rp-preset" data-days="${d}">${l}</button>`).join("")}
      </div>
      <div class="rp-presets"><!--''' + MARK + ''' takvim-->
        ${[["Bu ay", "buAy"], ["Geçen ay", "gecenAy"], ["Bu yıl", "buYil"]].map(([l, k]) =>
    `<button class="rp-cal" data-cal="${k}">${l}</button>`).join("")}
      </div>'''
if oldr not in src:
    print("HATA: render anchor bulunamadi (canli saha_desktop.js cekildi mi?)"); sys.exit(1)
src = src.replace(oldr, newr, 1)
print("[+] render rolling(6)+takvim(3) eklendi")

# 3) HANDLER: rolling click cal temizler + takvim handler
oldh = '''    m.querySelectorAll(".rp-preset").forEach(x => x.classList.toggle("on", x === b));
    ciz();
  }));
  m.querySelector(\'.rp-preset[data-days="30"]\')?.classList.add("on");  /* RAPOR_DEF30_DK_V1 */'''
newh = '''    m.querySelectorAll(".rp-preset").forEach(x => x.classList.toggle("on", x === b));
    m.querySelectorAll(".rp-cal").forEach(x => x.classList.remove("on"));  /* ''' + MARK + ''' */
    ciz();
  }));
  m.querySelectorAll(".rp-cal").forEach(b => b.addEventListener("click", () => {  /* ''' + MARK + ''' — takvim bazli aralik */
    const key = b.dataset.cal;
    const _ist = new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
    const [_iy, _im] = _ist.split("-").map(Number);
    const _fmt = (y, mo, d) => y + "-" + String(mo).padStart(2, "0") + "-" + String(d).padStart(2, "0");
    let f, t;
    if (key === "buAy") { f = _fmt(_iy, _im, 1); t = _ist; }
    else if (key === "buYil") { f = _fmt(_iy, 1, 1); t = _ist; }
    else { let py = _iy, pm = _im - 1; if (pm === 0) { pm = 12; py--; } f = _fmt(py, pm, 1); t = _fmt(py, pm, new Date(py, pm, 0).getDate()); }
    $("rp-from").value = f; $("rp-to").value = t;
    m.querySelectorAll(".rp-preset").forEach(x => x.classList.remove("on"));
    m.querySelectorAll(".rp-cal").forEach(x => x.classList.toggle("on", x === b));
    ciz();
  }));
  m.querySelector(\'.rp-preset[data-days="30"]\')?.classList.add("on");  /* RAPOR_DEF30_DK_V1 */'''
if oldh not in src:
    print("HATA: handler anchor bulunamadi (canli saha_desktop.js cekildi mi?)"); sys.exit(1)
src = src.replace(oldh, newh, 1)
print("[+] takvim handler + rolling cal-temizleme eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
