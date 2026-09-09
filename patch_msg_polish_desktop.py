# -*- coding: utf-8 -*-
# MSG_POLISH_DK_V1 (masaustu saha_desktop.js) — mesaj listesi cilasi:
#   baş harf avatarları, saatli tarih, boş konuşma soluk, arama kutusu, thread saat timezone.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "MSG_POLISH_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# D1) yardimcilar
OLD1 = "VIEWS.mesajlar = async (m) => {"
NEW1 = """function _dkAvatar(ad) {  /* MSG_POLISH_DK_V1 */
  const s = String(ad || "?").trim();
  const parts = s.split(/\\s+/).filter(Boolean);
  const ini = (((parts[0] || "?")[0] || "?") + (parts.length > 1 ? (parts[parts.length - 1][0] || "") : "")).toLocaleUpperCase("tr");
  let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360;
  return `<span style="flex-shrink:0;width:36px;height:36px;border-radius:50%;background:hsl(${h},52%,45%);color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:14px;font-weight:700">${esc(ini)}</span>`;
}
function _dkKisaTs(iso) {  /* MSG_POLISH_DK_V1 */
  try { return new Date(iso).toLocaleString("tr-TR", { timeZone: "Europe/Istanbul", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return ""; }
}
VIEWS.mesajlar = async (m) => {"""
assert s.count(OLD1) == 1, "VIEWS.mesajlar anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# D2) liste blogu
OLD2 = """    <div class="dk-det-yh">Bireysel Konuşmalar</div>
    ${konusmalar.map(k => `<div class="dk-pl" data-rep="${esc(k.rep_id)}" data-ad="${esc(k.rep_adi)}" style="cursor:pointer${k.okunmamis ? ";border-left:3px solid var(--mavi)" : ""}"><div class="dk-pl-top"><b class="firm">👤 ${esc(k.rep_adi)}</b>${k.okunmamis ? `<span class="pill p-info" style="margin-left:auto">${k.okunmamis} yeni</span>` : ""}</div>${k.son_mesaj ? `<div class="sub2" style="margin-top:3px">${k.son_mesaj.gonderen_rol === "rep" ? "↩ " : ""}${esc(k.son_mesaj.icerik.slice(0, 70))}${k.son_mesaj.icerik.length > 70 ? "…" : ""} · ${new Date(k.son_mesaj.created_at).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" })}</div>` : `<div class="sub2" style="margin-top:3px">Henüz mesaj yok</div>`}</div>`).join("")}
  </div>`;"""
NEW2 = """    <div class="dk-det-yh">Bireysel Konuşmalar</div>
    <input id="dk-msg-ara" placeholder="🔍 Temsilci ara…" style="width:100%;box-sizing:border-box;border:1px solid var(--cizgi);border-radius:9px;padding:9px 11px;font:inherit;margin-bottom:10px">
    <div id="dk-msg-liste">${konusmalar.map(k => `<div class="dk-pl dk-msg-satir" data-rep="${esc(k.rep_id)}" data-ad="${esc(k.rep_adi)}" data-ara="${esc((k.rep_adi||"").toLocaleLowerCase("tr"))}" style="display:flex;align-items:center;gap:10px;cursor:pointer${k.okunmamis ? ";border-left:3px solid var(--mavi)" : ""}${!k.son_mesaj ? ";opacity:.55" : ""}">${_dkAvatar(k.rep_adi)}<div style="flex:1;min-width:0"><div class="dk-pl-top"><b class="firm">${esc(k.rep_adi)}</b>${k.okunmamis ? `<span class="pill p-info" style="margin-left:auto">${k.okunmamis} yeni</span>` : ""}</div>${k.son_mesaj ? `<div class="sub2" style="margin-top:3px">${k.son_mesaj.gonderen_rol === "rep" ? "↩ " : ""}${esc(k.son_mesaj.icerik.slice(0, 70))}${k.son_mesaj.icerik.length > 70 ? "…" : ""} · ${_dkKisaTs(k.son_mesaj.created_at)}</div>` : `<div class="sub2" style="margin-top:3px">Henüz mesaj yok</div>`}</div></div>`).join("")}</div>
  </div>`;"""
assert s.count(OLD2) == 1, "list anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# D3) yayim yayimlar tarih -> saatli
OLD3 = """${yayimlar.map(y => `<div class="sub2" style="padding:3px 0">${esc(y.icerik.slice(0, 90))}${y.icerik.length > 90 ? "…" : ""} · ${new Date(y.created_at).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" })}</div>`).join("")}"""
NEW3 = """${yayimlar.map(y => `<div class="sub2" style="padding:3px 0">${esc(y.icerik.slice(0, 90))}${y.icerik.length > 90 ? "…" : ""} · ${_dkKisaTs(y.created_at)}</div>`).join("")}"""
assert s.count(OLD3) == 1, "yayim anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# D4) arama tel (msg-yayim handler'indan sonra)
OLD4 = '  m.querySelector("#msg-yayim").addEventListener("click", yayimMesaj);'
NEW4 = """  m.querySelector("#msg-yayim").addEventListener("click", yayimMesaj);
  const _dkAra = m.querySelector("#dk-msg-ara");  /* MSG_POLISH_DK_V1 */
  if (_dkAra) _dkAra.addEventListener("input", () => { const q = _dkAra.value.trim().toLocaleLowerCase("tr"); m.querySelectorAll(".dk-msg-satir").forEach(r => { r.style.display = (!q || (r.dataset.ara || "").includes(q)) ? "" : "none"; }); });"""
assert s.count(OLD4) == 1, "search anchor count=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

# D5) thread baloncuk saat timezone
OLD5 = 'const ts = new Date(x.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });'
NEW5 = 'const ts = new Date(x.created_at).toLocaleString("tr-TR", { timeZone: "Europe/Istanbul", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });  /* MSG_POLISH_DK_V1 */'
assert s.count(OLD5) == 1, "ts anchor count=%d" % s.count(OLD5)
s = s.replace(OLD5, NEW5, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MSG_POLISH_DK_V1 (masaustu)")
