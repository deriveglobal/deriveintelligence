#!/usr/bin/env python3
# SAHA_YENILE_BTN_V1 (client) — pull-to-refresh (PULL_REFRESH_OFF_V1) kapatildigi icin ust bara
#   acik bir "⟳ Yenile" butonu ekle. Aktif oda (roombar) VEYA aktif alt sekmeyi (nav) yeniden
#   yukler — eski PTR refresh() mantiginin aynisi; tam reload DEGIL (Face ID kilidini tetiklemez).
#   Idempotent (marker: SAHA_YENILE_BTN_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "SAHA_YENILE_BTN_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) Header: .saha-user icine ⟳ butonu (cikis ikonundan once)
old_h = '''<span class="saha-role">${S.role === "admin" ? "GM" : S.role === "manager" ? "Müdür" : "Saha"}</span><button id="saha-cikis"'''
new_h = '''<span class="saha-role">${S.role === "admin" ? "GM" : S.role === "manager" ? "Müdür" : "Saha"}</span><button id="saha-yenile" title="Yenile" style="background:none;border:none;color:#94a3b8;font-size:18px;cursor:pointer;padding:0 4px;line-height:1">⟳</button><!-- ''' + MARK + ''' --><button id="saha-cikis"'''
if old_h not in src:
    print("HATA: header saha-user anchor bulunamadi"); sys.exit(1)
src = src.replace(old_h, new_h, 1)
print("[+] header'a ⟳ Yenile butonu eklendi")

# 2) wireNav: saha-cikis handler'indan sonra yenile handler'i
old_w = '''    window.location.href = "/?app=1";
  });
  // ── Draggable FAB'''
new_w = '''    window.location.href = "/?app=1";
  });
  // ''' + MARK + ''' — ust bar yenile butonu (pull-to-refresh yerine)
  S.container.querySelector("#saha-yenile")?.addEventListener("click", () => {
    const btn = S.container.querySelector("#saha-yenile");
    if (btn) { btn.style.transition = "transform .6s"; btn.style.transform = "rotate(360deg)"; setTimeout(() => { btn.style.transition = ""; btn.style.transform = ""; }, 620); }
    const rb = S.container.querySelector(".saha-roombar");
    if (rb && getComputedStyle(rb).display !== "none") { const o = rb.querySelector(".saha-rtab.on"); if (o) { o.click(); return; } }
    const nv = S.container.querySelector(".saha-nav");
    if (nv && getComputedStyle(nv).display !== "none") { const t = nv.querySelector(".saha-tab.on"); if (t) { if (t.dataset.v === "daha") { if (typeof loadView === "function" && S && S.view) { loadView(S.view); return; } } t.click(); return; } }
    if (typeof loadView === "function" && S && S.view) loadView(S.view);
  });
  // ── Draggable FAB'''
if old_w not in src:
    print("HATA: wireNav saha-cikis/FAB anchor bulunamadi"); sys.exit(1)
src = src.replace(old_w, new_w, 1)
print("[+] wireNav'a yenile handler'i eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
