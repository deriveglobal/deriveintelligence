# -*- coding: utf-8 -*-
# MSG_POLISH_V1 (mobil saha.js) — mesaj listesi cilasi:
#   - baş harf avatarları (jenerik 👤 yerine renkli daire)
#   - liste tarihinde saat bilgisi (gün.ay saat:dk), Europe/Istanbul
#   - thread baloncuk saatine timeZone eklenir (kayma önlenir)
#   - boş konuşmalar soluk (opacity)
#   - temsilci arama kutusu
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "MSG_POLISH_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# M1) yardimci fonksiyonlar
OLD1 = "async function vMesajlar() {"
NEW1 = """function _msgAvatar(ad) {  /* MSG_POLISH_V1 */
  const s = String(ad || "?").trim();
  const parts = s.split(/\\s+/).filter(Boolean);
  const ini = (((parts[0] || "?")[0] || "?") + (parts.length > 1 ? (parts[parts.length - 1][0] || "") : "")).toLocaleUpperCase("tr");
  let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360;
  return `<span style="flex-shrink:0;width:34px;height:34px;border-radius:50%;background:hsl(${h},52%,45%);color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:13px;font-weight:700">${esc(ini)}</span>`;
}
function _msgKisaTs(iso) {  /* MSG_POLISH_V1 */
  try { return new Date(iso).toLocaleString("tr-TR", { timeZone: "Europe/Istanbul", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return ""; }
}
async function vMesajlar() {"""
assert s.count(OLD1) == 1, "vMesajlar anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# M2) yonetici liste blogu
OLD2 = """      main().innerHTML = `
        <button class="saha-cta" id="yayim-btn">📣 Toplu Mesaj Gönder</button>
        ${yayimlar.length ? `<div style="background:#fefce8;border:1px solid #fde047;border-radius:10px;padding:10px 12px;margin-bottom:10px">
          <div style="font-size:11px;font-weight:700;color:#854d0e;margin-bottom:6px">SON YAYIMLAR</div>
          ${yayimlar.map(y => `<div style="font-size:12px;color:#713f12;padding:4px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${new Date(y.created_at).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" })}</span></div>`).join("")}
        </div>` : ""}
        <div style="font-size:11px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.5px;margin:8px 0 6px">Bireysel Konuşmalar</div>
        ${konusmalar.map(k => `
          <div class="kart" data-rep-id="${k.rep_id}" style="${k.okunmamis ? "border-left:3px solid #0284c7;" : ""}">
            <div class="kart-ust">
              <b>👤 ${esc(k.rep_adi)}</b>
              ${k.okunmamis ? `<span class="rozet" style="background:#0284c7">${k.okunmamis} yeni</span>` : ""}
            </div>
            ${k.son_mesaj ? `<div class="kart-alt"><span style="color:#64748b;font-style:italic">${k.son_mesaj.gonderen_rol === "rep" ? "↩ " : ""}${esc(k.son_mesaj.icerik.slice(0,60))}${k.son_mesaj.icerik.length>60?"…":""}</span><span>${new Date(k.son_mesaj.created_at).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" })}</span></div>` : `<div class="kart-alt"><span style="color:#94a3b8;font-style:italic">Henüz mesaj yok</span></div>`}
          </div>`).join("")}
      `;"""
NEW2 = """      main().innerHTML = `
        <button class="saha-cta" id="yayim-btn">📣 Toplu Mesaj Gönder</button>
        ${yayimlar.length ? `<div style="background:#fefce8;border:1px solid #fde047;border-radius:10px;padding:10px 12px;margin-bottom:10px">
          <div style="font-size:11px;font-weight:700;color:#854d0e;margin-bottom:6px">SON YAYIMLAR</div>
          ${yayimlar.map(y => `<div style="font-size:12px;color:#713f12;padding:4px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${_msgKisaTs(y.created_at)}</span></div>`).join("")}
        </div>` : ""}
        <div style="font-size:11px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.5px;margin:8px 0 6px">Bireysel Konuşmalar</div>
        <input id="msg-ara" placeholder="🔍 Temsilci ara…" style="width:100%;box-sizing:border-box;border:1px solid #e2e8f0;border-radius:9px;padding:9px 11px;font:inherit;margin-bottom:8px">
        <div id="msg-liste">${konusmalar.map(k => `
          <div class="kart msg-satir" data-rep-id="${k.rep_id}" data-ara="${esc((k.rep_adi||"").toLocaleLowerCase("tr"))}" style="display:flex;align-items:center;gap:10px;${k.okunmamis ? "border-left:3px solid #0284c7;" : ""}${!k.son_mesaj ? "opacity:.55;" : ""}">
            ${_msgAvatar(k.rep_adi)}
            <div style="flex:1;min-width:0">
              <div class="kart-ust"><b>${esc(k.rep_adi)}</b>${k.okunmamis ? `<span class="rozet" style="background:#0284c7">${k.okunmamis} yeni</span>` : ""}</div>
              ${k.son_mesaj ? `<div class="kart-alt"><span style="color:#64748b;font-style:italic">${k.son_mesaj.gonderen_rol === "rep" ? "↩ " : ""}${esc(k.son_mesaj.icerik.slice(0,60))}${k.son_mesaj.icerik.length>60?"…":""}</span><span style="white-space:nowrap;margin-left:6px;color:#94a3b8">${_msgKisaTs(k.son_mesaj.created_at)}</span></div>` : `<div class="kart-alt"><span style="color:#94a3b8;font-style:italic">Henüz mesaj yok</span></div>`}
            </div>
          </div>`).join("")}</div>
      `;"""
assert s.count(OLD2) == 1, "list anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# M3) arama tel
OLD3 = '      main().querySelector("#yayim-btn")?.addEventListener("click", yayimMesajModal);'
NEW3 = """      main().querySelector("#yayim-btn")?.addEventListener("click", yayimMesajModal);
      const _msgAra = main().querySelector("#msg-ara");  /* MSG_POLISH_V1 */
      if (_msgAra) _msgAra.addEventListener("input", () => {
        const q = _msgAra.value.trim().toLocaleLowerCase("tr");
        main().querySelectorAll(".msg-satir").forEach(r => { r.style.display = (!q || (r.dataset.ara || "").includes(q)) ? "" : "none"; });
      });"""
assert s.count(OLD3) == 1, "search anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# M4) thread baloncuk saat timezone
OLD4 = '    const ts = new Date(m.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });'
NEW4 = '    const ts = new Date(m.created_at).toLocaleString("tr-TR", { timeZone: "Europe/Istanbul", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });  /* MSG_POLISH_V1 */'
assert s.count(OLD4) == 1, "ts anchor count=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MSG_POLISH_V1 (mobil)")
