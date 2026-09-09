# -*- coding: utf-8 -*-
# KAPSAM_MOB_V2 (saha.js) — mobil Kapsam okunabilirlik/amaç düzeltmesi:
#   - Amaç ÖNDE: "Karanlıktaki paran ₺X · N müşterine 90 gündür uğramadın".
#   - Liste kısa: en değerli 6 + "+N daha" genişletici (uzun scroll biter).
#   - Eşleşmemiş kör nokta katlanır (<details>).
#   - Aksiyon wiring delegasyona geçer (dinamik eklenen kartlar da çalışır).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_MOB_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "KAPSAM_MOB_V1" in s, "once KAPSAM_MOB_V1 olmali"

# 1) CSS: .kp-intro yerine .kp-lead + .kp-daha
o1 = '''      .kp-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:13px 15px;margin-bottom:12px}
      .kp-intro h3{margin:0 0 6px;font-size:13.5px;font-weight:800}.kp-intro p{margin:0;font-size:12px;line-height:1.55;color:var(--tx-1)}'''
n1 = '''      .kp-lead{background:linear-gradient(180deg,#FEF6E7,#FFFFFF);border:1px solid rgba(138,93,6,.22);border-radius:16px;padding:16px 17px;margin-bottom:14px}  /* KAPSAM_MOB_V2 */
      .kp-lead-k{font-size:11px;font-weight:700;color:var(--sari);text-transform:uppercase;letter-spacing:.05em}
      .kp-lead-n{font-size:34px;font-weight:800;color:var(--sari);letter-spacing:-.02em;line-height:1.05;margin:4px 0 7px;font-variant-numeric:tabular-nums}
      .kp-lead-p{font-size:13px;color:var(--tx-0);line-height:1.5}.kp-lead-p b{font-weight:800}
      .kp-lead-b{display:flex;gap:8px;align-items:center;margin-top:11px;font-size:11.5px;font-weight:700;color:var(--tx-1)}.kp-dot{color:var(--tx-3)}
      .kp-daha{width:100%;margin:2px 0 4px;padding:11px;border:1px solid var(--cizgi);border-radius:11px;background:var(--zemin-1);color:var(--tx-1);font-family:inherit;font-size:12.5px;font-weight:700;cursor:pointer}'''
assert s.count(o1) == 1, "css anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) HTML top: intro+hero -> lead
o2 = '''      <div class="kp-intro"><h3>📍 Kapsam & Beyaz Alan</h3><p>${yon ? "Ekibin nereye dokunduğu ve <b>dokunulmayan değerli müşteriler</b>." : "<b>Senin</b> kitabının ne kadarını tarıyorsun ve hangi <b>değerli müşterin karanlıkta</b>. Gittiysen ✔️ de, listeden düşer."}</p></div>
      <div class="kp-hero">
        <div class="kp-ring"><svg width="88" height="88" viewBox="0 0 88 88"><circle cx="44" cy="44" r="${R}" fill="none" stroke="var(--zemin-2)" stroke-width="8"/><circle cx="44" cy="44" r="${R}" fill="none" stroke="var(--yesil)" stroke-width="8" stroke-linecap="round" stroke-dasharray="${CIRC.toFixed(1)}" stroke-dashoffset="${off.toFixed(1)}"/></svg><div class="c"><b>${o.kapsam || 0}%</b><small>Kapsam</small></div></div>
        <div class="kp-hv"><div class="g">${kisa(o.beyaz_ciro || 0)}</div><div class="l">karanlıktaki ciro · ${o.beyaz_sayi || 0} müşteri</div><div class="s">${o.ulasilan || 0}/${o.portfoy || 0} müşteriye ulaşıldı · son 90 gün</div></div>
      </div>'''
n2 = '''      <div class="kp-lead">
        <div class="kp-lead-k">💰 ${yon ? "Ekibin karanlıktaki cirosu" : "Karanlıktaki paran"}</div>
        <div class="kp-lead-n">${kisa(o.beyaz_ciro || 0)}</div>
        <div class="kp-lead-p">${(o.beyaz_sayi || 0) > 0 ? `<b>${o.beyaz_sayi}</b> değerli müşteri${yon ? "ye ekip" : "ne"} <b>90 gündür</b> uğra${yon ? "madı" : "madın"} — o para orada duruyor.` : "Değerli müşterilerinin hepsine dokunmuşsun 👏"}</div>
        <div class="kp-lead-b"><span>📍 Kapsam %${o.kapsam || 0}</span><span class="kp-dot">·</span><span>${o.ulasilan || 0}/${o.portfoy || 0} müşteriye ulaştın</span></div>
      </div>'''
assert s.count(o2) == 1, "top anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) HTML liste: kısa + genişletici + katlanır eşleşmemiş
o3 = '''      <div class="kp-sec">💰 Dokunulmayan değerli müşteriler</div>
      ${beyaz.length ? beyaz.map(card).join("") : `<div class="kp-empty">🎉 Beyaz alan yok — hepsine dokunmuşsun.</div>`}
      ${esiz.length ? `<div class="kp-sec">⚠️ Eşleşmemiş — kör nokta (${o.eslesmemis_sayi || 0})</div>${esiz.slice(0, 30).map(esizCard).join("")}` : ""}'''
n3 = '''      <div class="kp-sec">${yon ? "En değerli — harekete geçir" : "İşte en değerli · dokun, kapat"}</div>
      <div id="kp-liste">${beyaz.length ? beyaz.slice(0, 6).map(card).join("") : `<div class="kp-empty">🎉 Beyaz alan yok — hepsine dokunmuşsun.</div>`}</div>
      ${beyaz.length > 6 ? `<button class="kp-daha" data-daha="1">+ ${beyaz.length - 6} müşteri daha göster</button>` : ""}
      ${esiz.length ? `<details class="kp-how"><summary>⚠️ Eşleşmemiş kör nokta · ${o.eslesmemis_sayi || 0}</summary><div style="padding:0 2px 10px">${esiz.slice(0, 20).map(esizCard).join("")}</div></details>` : ""}'''
assert s.count(o3) == 1, "list anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) wiring: per-button -> delegasyon + daha
o4 = '''    box.querySelectorAll("[data-aks]").forEach(b => b.addEventListener("click", () => {
      const mid = b.dataset.mid, tur = b.dataset.aks, row = b.closest(".kp-row"); if (!row) return;'''
n4 = '''    box.addEventListener("click", (ev) => {  /* KAPSAM_MOB_V2 delegasyon */
      const _dh = ev.target.closest("[data-daha]");
      if (_dh) { const _w = box.querySelector("#kp-liste"); if (_w) _w.insertAdjacentHTML("beforeend", beyaz.slice(6).map(card).join("")); _dh.remove(); return; }
      const b = ev.target.closest("[data-aks]"); if (!b) return;
      const mid = b.dataset.mid, tur = b.dataset.aks, row = b.closest(".kp-row"); if (!row) return;'''
assert s.count(o4) == 1, "wire-open anchor=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

# 5) wiring kapanış: forEach `}));` -> delegasyon `});`
o5 = 'gerekce_metin: txt || null }); });\n    }));'
n5 = 'gerekce_metin: txt || null }); });\n    });'
assert s.count(o5) == 1, "wire-close anchor=%d" % s.count(o5)
s = s.replace(o5, n5, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_MOB_V2 (saha.js) — amaç önde, kısa liste + genişletici, katlanır kör nokta")
