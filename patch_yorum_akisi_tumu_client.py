#!/usr/bin/env python3
# YORUM_AKISI_TUMU_V1 (client, mobil) — Yorumlar kartina [Odak|Tümü] gecisi.
#   Odak (varsayilan, degismez): okunmamis. Tümü: okunmus+okunmamis (okunmuslar soluk + ✓).
#   Tümü'ye gecince /api/saha/yorum-akisi?mod=tumu fetch + #yrm-liste yeniden render + satir wire.
#   Onkosul: YORUM_AKISI_ODAK_V1 (client) canli. Idempotent (marker: YORUM_AKISI_TUMU_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_AKISI_TUMU_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# --- A) yorumHtml blok -> _yrmSatir + _yrmRender + yorumHtml ---
oldA = '''    const yorumHtml = (_yorumAkisi.yorumlar || []).length === 0
      ? empty("Yeni yorum yok ✓")
      : _yorumAkisi.yorumlar.map(y => {  /* YORUM_AKISI_ODAK_V1 — odak: okunmamis bildirim satirlari */
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
newA = '''    const _yrmSatir = (y) => {  /* ''' + MARK + ''' — okundu ise soluk + ✓ */
      const _duy = y.tur === "duyuru";
      const _nav = _duy ? `data-did="${y.ref_id}"` : `data-zid="${y.ref_id}"`;
      const _tag = _duy ? "📢" : "🚗";
      const _zaman = new Date(y.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
      const _op = y.okundu ? "opacity:.55" : "";
      const _ok = y.okundu ? ` <span style="font-size:10px;color:#16a34a">✓</span>` : "";
      return `
          <div class="kart" ${_nav} style="padding:10px 12px;margin-bottom:6px;cursor:pointer;${_op}">
            <div class="kart-ust" style="align-items:flex-start">
              <span style="font-size:12px;color:#334155;line-height:1.35;white-space:pre-wrap;word-break:break-word">${_tag} ${esc(y.govde || "")}${_ok}</span>
              <span style="font-size:11px;color:#94a3b8;white-space:nowrap;margin-left:8px">${_zaman}</span>
            </div>
          </div>`;
    };
    const _yrmRender = (arr, mod) => (arr || []).length === 0
      ? empty(mod === "tumu" ? "Bu yıl yorum yok" : "Yeni yorum yok ✓")
      : (arr).map(_yrmSatir).join("");
    const yorumHtml = _yrmRender(_yorumAkisi.yorumlar, "odak");'''
if oldA not in src:
    print("HATA: ODAK yorumHtml anchor bulunamadi"); sys.exit(1)
src = src.replace(oldA, newA, 1)
print("[+] A: _yrmSatir/_yrmRender/yorumHtml")

# --- B) secBlock body: toggle + #yrm-liste ---
oldB = '''        ${secBlock("🗨️", "Yorumlar", _yorumAkisi.okunmamis || null, "#0284c7", yorumHtml, { kapali: true })}  <!-- YORUM_AKISI_V1 -->'''
newB = '''        ${secBlock("🗨️", "Yorumlar", _yorumAkisi.okunmamis || null, "#0284c7",
          `<div class="yrm-mod" style="display:flex;gap:6px;margin-bottom:8px"><!-- ''' + MARK + ''' -->
             <button class="yrm-tab" data-mod="odak" style="flex:1;padding:5px 0;border:1px solid #0284c7;border-radius:6px;background:#0284c7;color:#fff;font-size:12px;font-weight:600;cursor:pointer">Odak</button>
             <button class="yrm-tab" data-mod="tumu" style="flex:1;padding:5px 0;border:1px solid #e5e7eb;border-radius:6px;background:#fff;color:#374151;font-size:12px;font-weight:600;cursor:pointer">Tümü</button>
           </div>
           <div id="yrm-liste">` + yorumHtml + `</div>`, { kapali: true })}  <!-- YORUM_AKISI_V1 YORUM_AKISI_TUMU_V1 -->'''
if oldB not in src:
    print("HATA: secBlock Yorumlar anchor bulunamadi"); sys.exit(1)
src = src.replace(oldB, newB, 1)
print("[+] B: toggle + #yrm-liste")

# --- C) _yrmYukle + wiring (data-did wiring sonrasi) ---
oldC = '''    main().querySelectorAll("[data-did]").forEach(el =>
      el.addEventListener("click", () => duyuruDetayModal(el.dataset.did)));'''
newC = oldC + '''
    const _yrmWire = (box) => {  /* ''' + MARK + ''' */
      if (!box) return;
      box.querySelectorAll("[data-zid]").forEach(el => el.addEventListener("click", () => ziyaretDetayModal(el.dataset.zid)));
      box.querySelectorAll("[data-did]").forEach(el => el.addEventListener("click", () => duyuruDetayModal(el.dataset.did)));
    };
    async function _yrmYukle(mod) {
      const box = document.getElementById("yrm-liste"); if (!box) return;
      box.style.opacity = ".5";
      let d = { yorumlar: [] };
      try { d = await api("/api/saha/yorum-akisi" + (mod === "tumu" ? "?mod=tumu" : "")); } catch (e) {}
      box.innerHTML = _yrmRender(d.yorumlar, mod);
      box.style.opacity = "1";
      _yrmWire(box);
      main().querySelectorAll(".yrm-tab").forEach(b => {
        const on = b.dataset.mod === mod;
        b.style.background = on ? "#0284c7" : "#fff";
        b.style.color = on ? "#fff" : "#374151";
        b.style.borderColor = on ? "#0284c7" : "#e5e7eb";
      });
    }
    main().querySelectorAll(".yrm-tab").forEach(b =>
      b.addEventListener("click", () => _yrmYukle(b.dataset.mod)));'''
if oldC not in src:
    print("HATA: data-did wiring anchor bulunamadi"); sys.exit(1)
src = src.replace(oldC, newC, 1)
print("[+] C: _yrmYukle + toggle wiring")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
