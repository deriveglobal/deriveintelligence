# -*- coding: utf-8 -*-
# BUGUN_KATLA_V1 + BUGUN_INBOX_V1 (mobil saha.js) — iki iyilestirme:
#   1) Bugun bolumleri KATLANABILIR (tikla ac/kapa). Ikincil bolumler (Duyuru/Mesaj/Teklif)
#      varsayilan KAPALI -> ekran bastan bosalir. Ziyaretler + Hatirlatmalar acik gelir.
#   2) YONETICI icin "Bugunun Ziyaretleri" bir okunmamis gelen-kutusu: gorulmus (gordum)
#      ziyaret Bugun'den dusr; acilinca aninda listeden cikar. REP'te liste aynen kalir
#      (rep icin Bugun gunluk is listesi; kaybolmamali).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "BUGUN_KATLA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) secBlock -> katlanabilir kart
OLD1 = '''    const secBlock = (ico, title, badge, badgeColor, body) => `
      <div style="margin-bottom:18px">
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
          <span style="font-size:14px;font-weight:700;color:#1e293b">${ico} ${title}</span>
          ${badge ? `<span style="background:${badgeColor};color:#fff;border-radius:10px;font-size:10px;font-weight:700;padding:2px 8px">${badge}</span>` : ""}
        </div>
        ${body}
      </div>`;'''
NEW1 = '''    const secBlock = (ico, title, badge, badgeColor, body, opts) => {  /* BUGUN_KATLA_V1 */
      const acik = !(opts && opts.kapali);
      return `
      <div class="sec-blk" style="margin-bottom:12px;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;background:#fff">
        <button type="button" data-sec-toggle style="display:flex;align-items:center;gap:8px;width:100%;padding:12px 14px;background:none;border:none;cursor:pointer;text-align:left;-webkit-tap-highlight-color:transparent">
          <span style="font-size:14px;font-weight:700;color:#1e293b">${ico} ${title}</span>
          ${badge ? `<span class="sec-badge" style="background:${badgeColor};color:#fff;border-radius:10px;font-size:10px;font-weight:700;padding:2px 8px">${badge}</span>` : ""}
          <span class="sec-ok" style="margin-left:auto;color:#94a3b8;font-size:11px;transform:rotate(${acik ? "0" : "-90"}deg)">▼</span>
        </button>
        <div class="sec-bd" style="padding:0 14px 12px;${acik ? "" : "display:none"}">${body}</div>
      </div>`;
    };'''
assert s.count(OLD1) == 1, "secBlock anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) ziyaretHtml -> yoneticide gorulmemis filtre
OLD2 = '''    const ziyaretHtml = ziyaretler.length === 0
      ? empty("Bugün planlanmış ziyaret yok")
      : ziyaretler.map(z => `'''
NEW2 = '''    const bugunZiy = (S.role === "rep") ? ziyaretler : ziyaretler.filter(z => !z.gordum);  /* BUGUN_INBOX_V1 */
    const ziyaretHtml = bugunZiy.length === 0
      ? empty(S.role === "rep" ? "Bugün planlanmış ziyaret yok" : "Tüm bugünkü ziyaretler görüldü ✓")
      : bugunZiy.map(z => `'''
assert s.count(OLD2) == 1, "ziyaretHtml anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# 3) secBlock cagrilari -> ziyaret rozeti bugunZiy; ikincil bolumler kapali
OLD3 = '''        ${secBlock("📅", "Bugünün Ziyaretleri", ziyaretler.length || null, "#0ea5e9", ziyaretHtml)}
        ${secBlock("📢", "Okunmamış Duyurular", duyurular_okunmamis.length || null, "#dc2626", duyuruHtml)}
        ${secBlock("💬", "Mesajlar", mesaj_okunmamis || null, "#0284c7", mesajHtml)}
        ${secBlock("💰", "Bekleyen Teklifler", teklifler.length || null, "#d97706", teklifHtml)}'''
NEW3 = '''        ${secBlock("📅", "Bugünün Ziyaretleri", bugunZiy.length || null, "#0ea5e9", ziyaretHtml)}
        ${secBlock("📢", "Okunmamış Duyurular", duyurular_okunmamis.length || null, "#dc2626", duyuruHtml, { kapali: true })}
        ${secBlock("💬", "Mesajlar", mesaj_okunmamis || null, "#0284c7", mesajHtml, { kapali: true })}
        ${secBlock("💰", "Bekleyen Teklifler", teklifler.length || null, "#d97706", teklifHtml, { kapali: true })}'''
assert s.count(OLD3) == 1, "secBlock-calls anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# 4) visit handler -> katla toggle + yoneticide acinca satiri dusr
OLD4 = '''    // visit card → detail
    main().querySelectorAll("[data-zid]").forEach(el =>
      el.addEventListener("click", e => {
        if (e.target.closest("[data-checkin]")) return;
        ziyaretDetayModal(el.dataset.zid);
      }));'''
NEW4 = '''    // section collapse/expand  /* BUGUN_KATLA_V1 */
    main().querySelectorAll("[data-sec-toggle]").forEach(btn =>
      btn.addEventListener("click", () => {
        const blk = btn.closest(".sec-blk"); if (!blk) return;
        const bd = blk.querySelector(".sec-bd"); const ok = blk.querySelector(".sec-ok");
        const gizli = bd.style.display === "none";
        bd.style.display = gizli ? "" : "none";
        if (ok) ok.style.transform = gizli ? "rotate(0deg)" : "rotate(-90deg)";
      }));

    // visit card → detail
    main().querySelectorAll("[data-zid]").forEach(el =>
      el.addEventListener("click", e => {
        if (e.target.closest("[data-checkin]")) return;
        const zid = el.dataset.zid;
        const blk = el.closest(".sec-blk");
        ziyaretDetayModal(zid);
        if (S.role !== "rep") {  /* BUGUN_INBOX_V1: yoneticide gorulen ziyaret Bugun'den dusr */
          el.remove();
          if (blk) {
            const bd = blk.querySelector(".sec-bd");
            const kalan = bd ? bd.querySelectorAll("[data-zid]").length : 0;
            const bdg = blk.querySelector(".sec-badge");
            if (bdg) { if (kalan) bdg.textContent = String(kalan); else bdg.remove(); }
            if (!kalan && bd) bd.innerHTML = `<div style="color:#94a3b8;font-size:13px;font-style:italic;padding:6px 0">Tüm bugünkü ziyaretler görüldü ✓</div>`;
          }
        }
      }));'''
assert s.count(OLD4) == 1, "visit-handler anchor count=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_KATLA_V1 + BUGUN_INBOX_V1 (mobil)")
