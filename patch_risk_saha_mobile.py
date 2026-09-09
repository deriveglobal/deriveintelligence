# -*- coding: utf-8 -*-
# RISK_SAHA_V1 (mobil) — Rapor'a "🚨 Risk" sekmesi (Risk Radarı, dar ekrana yığılmış).
#   Açıklama + özet + kritik müşteri kartları (soğuk=kırmızı) + temsilci risk rollup + rep-alanı seçici (yönetici).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "RISK_SAHA_V1" in s and "async function rpRisk" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) sekme — ciro'dan sonra
t_old = '    ["ciro",        "💰 Ciro"],  /* ZIYARET_CIRO_UI_V1 */'
t_new = t_old + '\n    ["risk",        "🚨 Risk"],  /* RISK_SAHA_V1 */'
assert s.count(t_old) == 1, "tab anchor=%d" % s.count(t_old)
s = s.replace(t_old, t_new, 1)

# 2) dispatch
d_old = '      case "ciro":        rpCiro();        break;'
d_new = d_old + '\n      case "risk":        rpRisk();        break;'
assert s.count(d_old) == 1, "dispatch anchor=%d" % s.count(d_old)
s = s.replace(d_old, d_new, 1)

# 3) rpRisk — rpCiro'dan önce
anchor = "  async function rpCiro() {"
RP = r'''  async function rpRisk() {  /* RISK_SAHA_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const d = await api(`/api/saha/rapor/risk-saha?_=1${tipQS()}`);
      const box = icerik(); if (!box) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const ALAN = { TICARI: { ad: "Ticari" }, TUKETICI: { ad: "Tüketici" } };
      const repAlan = (t) => { const a = String(t || "").toUpperCase(); return a === "TUKETICI" ? "TUKETICI" : a === "TICARI" ? "TICARI" : null; };
      const sev = (g) => (g === null || g > 30) ? "hot" : (g > 14 ? "warm" : "ok");
      const visLbl = (g) => g === null ? ["Hiç ziyaret", "cold"] : g > 30 ? [g + " gün önce", "cold"] : g > 14 ? [g + " gün önce", "warm"] : [g + " gün önce", "fresh"];
      const CSS = `<style>
        .rk{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#0284c7;color-scheme:light;padding:10px 12px 90px;color:var(--tx-0)}
        .rk *{box-sizing:border-box}
        .rk-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:13px 15px;margin-bottom:12px}
        .rk-intro h3{margin:0 0 6px;font-size:13.5px;font-weight:800;color:var(--tx-0)}
        .rk-intro p{margin:0;font-size:12px;line-height:1.55;color:var(--tx-1)}
        .rk-intro .calc{display:flex;flex-direction:column;gap:5px;margin-top:9px;padding-top:9px;border-top:1px solid var(--cizgi)}
        .rk-intro .calc div{font-size:11.5px;color:var(--tx-1);line-height:1.5}.rk-intro .calc b{color:var(--tx-0)}
        .rk-intro code{background:var(--zemin-2);padding:1px 5px;border-radius:5px;font-size:10.5px}
        .rk-grid{display:grid;gap:8px;grid-template-columns:repeat(2,1fr)}
        .rk-hero{grid-column:span 2;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:15px;padding:15px}
        .rk-hero.al{border-color:rgba(196,61,40,.3);background:linear-gradient(180deg,#fff,#fdf6f4)}
        .rk-hero .l{font-size:12px;font-weight:600;color:var(--tx-1)}.rk-hero .n{font-size:30px;font-weight:800;letter-spacing:-.02em;color:var(--kirmizi);margin-top:2px;font-variant-numeric:tabular-nums}
        .rk-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:11px 12px}
        .rk-tile .n{font-size:19px;font-weight:800;color:var(--tx-0);line-height:1;font-variant-numeric:tabular-nums}.rk-tile .l{font-size:10.5px;color:var(--tx-1);margin-top:5px;font-weight:500}
        .rk-sec{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.05em;margin:18px 2px 8px;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap}
        .rk-fil{display:flex;gap:4px}
        .rk-fil button{border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-family:inherit;font-size:11px;font-weight:700;padding:4px 10px;border-radius:999px;cursor:pointer;text-transform:none;letter-spacing:0}
        .rk-fil button.on{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}
        .rl{display:flex;flex-direction:column;gap:8px}
        .rl-row{position:relative;overflow:hidden;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:11px 13px 11px 15px}
        .rl-row:active{background:var(--zemin-2)}
        .rl-sev{position:absolute;left:0;top:0;bottom:0;width:4px}.rl-sev.hot{background:var(--kirmizi)}.rl-sev.warm{background:var(--sari)}.rl-sev.ok{background:var(--yesil)}
        .rl-top{display:flex;align-items:baseline;gap:10px}
        .rl-firm{flex:1;min-width:0;font-size:13.5px;font-weight:700;color:var(--tx-0);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .rl-amt{font-size:16px;font-weight:800;color:var(--tx-0);font-variant-numeric:tabular-nums;white-space:nowrap}
        .rl-meta{font-size:11px;color:var(--tx-2);margin-top:5px;display:flex;gap:8px;flex-wrap:wrap;align-items:center}
        .rl-meta .rep{color:var(--tx-1);font-weight:600}
        .rl-meta .vis.cold{color:var(--kirmizi);font-weight:700}.rl-meta .vis.warm{color:var(--sari);font-weight:700}.rl-meta .vis.fresh{color:var(--yesil);font-weight:700}
        .rl-lim{font-size:9px;font-weight:800;color:var(--kirmizi);background:var(--kirmizi-z);padding:1px 6px;border-radius:999px}
        .rr{display:flex;flex-direction:column;gap:8px}
        .rr-row{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:12px 13px}
        .rr-top{display:flex;align-items:baseline;justify-content:space-between;gap:8px}
        .rr-nm{font-size:13.5px;font-weight:700;color:var(--tx-0)}.rr-tot{font-size:15px;font-weight:800;color:var(--tx-0);font-variant-numeric:tabular-nums}
        .rr-sub{font-size:11px;color:var(--tx-2);margin-top:2px}
        .rr-bar{margin-top:9px}.rr-bar .bl{display:flex;justify-content:space-between;font-size:10px;color:var(--tx-2);font-weight:600;margin-bottom:3px}.rr-bar .bl b{color:var(--kirmizi);font-variant-numeric:tabular-nums}
        .rr-track{height:7px;border-radius:999px;background:var(--zemin-2);overflow:hidden}.rr-fill{height:100%;border-radius:999px;background:linear-gradient(90deg,#C43D28,#e5734f)}
        .rk-lgnd{display:flex;gap:12px;font-size:10.5px;color:var(--tx-2);font-weight:600}.rk-lgnd i{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:4px;vertical-align:middle}
        .rk-empty{color:var(--tx-2);text-align:center;padding:18px;font-size:12px}
      </style>`;
      const INTRO = `<div class="rk-intro"><h3>🚨 Risk Radarı — ne işe yarar?</h3>
        <p>Vadesi geçmiş alacağı olan müşterileri <b>ziyaret güncelliğiyle</b> çaprazlar. Asıl tehlike: <b>parası gecikmiş ama kimsenin uğramadığı "soğuk" müşteriler</b>. (Yalnız ERP'ye bağlı müşteride gecikmiş görünür → eşleştirmeyi teşvik eder.)</p>
        <div class="calc">
          <div><b>Gecikmiş</b> = <code>vadesi_gecmis</code> (FIFO; SAP alacak yaşlandırma), <code>musteri_kodu</code> ile eşleşir.</div>
          <div><b>Son ziyaret</b> = en son tamamlanmış ziyaret (paylaşımlı havuz).</div>
          <div><b>🥶 Soğuk</b> = gecikmiş + 30+ gün ya da hiç ziyaret — en acil.</div>
        </div></div>`;
      const ms = d.musteriler || [];
      const rowsHtml = (arr) => arr.slice().sort((a, b) => { const sa = sev(a.gun) === "hot" ? 1 : 0, sb = sev(b.gun) === "hot" ? 1 : 0; if (sa !== sb) return sb - sa; return (b.overdue || 0) - (a.overdue || 0); })
        .map(m => { const sv = sev(m.gun), [vl, vc] = visLbl(m.gun), al = repAlan(m.saha_tip);
          return `<div class="rl-row" data-mid="${esc(m.id)}"><div class="rl-sev ${sv}"></div>
            <div class="rl-top"><div class="rl-firm">${esc(m.firma)}</div><div class="rl-amt">${kisa(m.overdue)}</div></div>
            <div class="rl-meta"><span class="rep">${esc(m.rep || "—")}</span><span>· ${al ? ALAN[al].ad : "—"}</span><span class="vis ${vc}">${vl}</span>${m.limit ? `<span class="rl-lim">Limit aşımı</span>` : ""}</div></div>`; }).join("");
      const tiles = (arr, etiket) => { const tp = arr.reduce((s, m) => s + (m.overdue || 0), 0), sg = arr.filter(m => m.gun === null || m.gun > 30).reduce((s, m) => s + (m.overdue || 0), 0), lm = arr.filter(m => m.limit).length;
        return `<div class="rk-grid">
          <div class="rk-hero al"><div class="l">Toplam gecikmiş · ${etiket}</div><div class="n">${kisa(tp)}</div></div>
          <div class="rk-tile"><div class="n" style="color:var(--kirmizi)">${kisa(sg)}</div><div class="l">🥶 Soğuk gecikmiş</div></div>
          <div class="rk-tile"><div class="n">${arr.length}</div><div class="l">Riskli müşteri</div></div></div>`; };
      const lgnd = `<span class="rk-lgnd"><span><i style="background:#C43D28"></i>Soğuk</span><span><i style="background:#8A5D06"></i>İzle</span><span><i style="background:#106B4A"></i>Taze</span></span>`;
      const bindRows = () => box.querySelectorAll(".rl-row[data-mid]").forEach(rw => rw.addEventListener("click", async () => {
        const id = rw.dataset.mid; let c = (S.musteriler || []).find(x => x.id === id);
        if (!c) { try { const res = await api(`/api/saha/musteriler/${id}`); c = res.musteri || res; } catch (e) {} }
        if (c) musteriDetayModal(c);
      }));
      if (d.rol === "rep") {
        box.innerHTML = CSS + `<div class="rk">${INTRO}${tiles(ms, "portföyün")}
          <div class="rk-sec"><span>🚨 Kritik müşterilerin</span>${lgnd}</div>
          ${ms.length ? `<div class="rl">${rowsHtml(ms)}</div>` : `<div class="rk-empty">Gecikmiş alacaklı müşterin yok. 👍</div>`}</div>`;
        bindRows();
      } else {
        const render = (field) => {
          const F = ms.filter(m => !field || repAlan(m.saha_tip) === field);
          const RR = {}; F.forEach(m => { const r = RR[m.rep_id] || (RR[m.rep_id] = { rep: m.rep, alan: repAlan(m.saha_tip), overdue: 0, cold: 0, n: 0 }); r.overdue += m.overdue || 0; r.n++; if (m.gun === null || m.gun > 30) r.cold += m.overdue || 0; });
          const rrArr = Object.values(RR).sort((a, b) => b.cold - a.cold); const maxCold = Math.max(...rrArr.map(r => r.cold), 1);
          const rrRows = rrArr.map(r => `<div class="rr-row"><div class="rr-top"><div><div class="rr-nm">${esc(r.rep || "—")} <span style="font-size:10px;color:var(--tx-2);font-weight:700">· ${r.alan ? ALAN[r.alan].ad : "—"}</span></div><div class="rr-sub"><b>${r.n}</b> riskli müşteri</div></div><div class="rr-tot">${kisa(r.overdue)}</div></div>
            <div class="rr-bar"><div class="bl"><span>Soğuk (ziyaretsiz) gecikmiş</span><b>${kisa(r.cold)}</b></div><div class="rr-track"><div class="rr-fill" style="width:${Math.max(3, Math.round(r.cold / maxCold * 100))}%"></div></div></div></div>`).join("") || `<div class="rk-empty">Bu sahada riskli müşteri yok.</div>`;
          const fb = (f, l) => `<button data-f="${f}" class="${field === f ? "on" : ""}">${l}</button>`;
          box.innerHTML = CSS + `<div class="rk">${INTRO}${tiles(F, field ? ALAN[field].ad + " saha" : "portföy")}
            <div class="rk-sec"><span>🚨 Kritik müşteriler</span><div class="rk-fil" id="rk-fil">${fb("", "Tümü")}${fb("TICARI", "Ticari")}${fb("TUKETICI", "Tüketici")}</div></div>
            <div style="margin:-2px 2px 8px">${lgnd}</div>
            ${F.length ? `<div class="rl">${rowsHtml(F)}</div>` : `<div class="rk-empty">Bu sahada gecikmiş alacaklı müşteri yok.</div>`}
            <div class="rk-sec"><span>Temsilci bazında risk</span></div>
            <div class="rr">${rrRows}</div></div>`;
          const fil = box.querySelector("#rk-fil"); if (fil) fil.querySelectorAll("button").forEach(b => b.addEventListener("click", () => render(b.dataset.f)));
          bindRows();
        };
        render("");
      }
    } catch (e) { const box = icerik(); if (box) box.innerHTML = hata(e); }
  }
  async function rpCiro() {'''
assert s.count(anchor) == 1, "rpCiro anchor=%d" % s.count(anchor)
s = s.replace(anchor, RP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RISK_SAHA_V1 (mobil)")
