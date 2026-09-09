# -*- coding: utf-8 -*-
# RISK_SAHA_DK_V1 (masaüstü) — Rapor'a "🚨 Risk" sekmesi (Risk Radarı).
#   Açıklama + özet + kritik müşteri listesi (soğuk=kırmızı) + temsilci risk rollup + rep-alanı seçici (yönetici).
#   Açık token'lar .rk'ye sabit (koyu kabukta bile açık).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RISK_SAHA_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) sekme — ciro'dan sonra
t_old = '    ["ciro", "💰 Ciro"],  /* CIRO_UI2_DK_V1 */'
t_new = t_old + '\n    ["risk", "🚨 Risk"],  /* RISK_SAHA_DK_V1 */'
assert s.count(t_old) == 1, "tab anchor=%d" % s.count(t_old)
s = s.replace(t_old, t_new, 1)

# 2) RENDER map
m_old = "const RENDER = { ozet: rpOzet, ciro: rpCiro,"
m_new = "const RENDER = { ozet: rpOzet, ciro: rpCiro, risk: rpRisk,"
assert s.count(m_old) == 1, "render anchor=%d" % s.count(m_old)
s = s.replace(m_old, m_new, 1)

# 3) rpRisk — rpCiro'dan önce
anchor = "  async function rpCiro() {"
RP = r'''  async function rpRisk() {  /* RISK_SAHA_DK_V1 */
    const el = icerik(); if (!el) return; el.innerHTML = load();
    try {
      const d = await api(`/api/saha/rapor/risk-saha?_=1${tipQS()}`);
      const box = icerik(); if (!box) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const ALAN = { TICARI: { ad: "Ticari" }, TUKETICI: { ad: "Tüketici" } };
      const repAlan = (t) => { const a = String(t || "").toUpperCase(); return a === "TUKETICI" ? "TUKETICI" : a === "TICARI" ? "TICARI" : null; };
      const sev = (g) => (g === null || g > 30) ? "hot" : (g > 14 ? "warm" : "ok");
      const visLbl = (g) => g === null ? ["Hiç ziyaret", "cold"] : g > 30 ? [g + " gün önce", "cold"] : g > 14 ? [g + " gün önce", "warm"] : [g + " gün önce", "fresh"];
      const CSS = `<style>
        .rk{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#2563eb;color-scheme:light;color:var(--tx-0);font-family:var(--sans,-apple-system,'Segoe UI',system-ui,sans-serif)}
        .rk *{box-sizing:border-box}
        .rk-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:15px 17px;margin-bottom:14px}
        .rk-intro h3{margin:0 0 6px;font-size:14px;font-weight:800;color:var(--tx-0)}
        .rk-intro p{margin:0;font-size:12.5px;line-height:1.6;color:var(--tx-1)}
        .rk-intro .calc{display:flex;flex-direction:column;gap:5px;margin-top:9px;padding-top:10px;border-top:1px solid var(--cizgi)}
        .rk-intro .calc div{font-size:12px;color:var(--tx-1);line-height:1.5}.rk-intro .calc b{color:var(--tx-0)}
        .rk-intro code{background:var(--zemin-2);padding:1px 6px;border-radius:5px;font-size:11px}
        .rk-grid{display:grid;gap:10px;grid-template-columns:repeat(4,1fr)}
        .rk-hero{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:16px;padding:18px}
        .rk-hero.al{border-color:rgba(196,61,40,.3);background:linear-gradient(180deg,#fff,#fdf6f4)}
        .rk-hero .l{font-size:12px;font-weight:600;color:var(--tx-1)}.rk-hero .n{font-size:34px;font-weight:800;letter-spacing:-.02em;color:var(--tx-0);margin-top:2px;font-variant-numeric:tabular-nums}.rk-hero.al .n{color:var(--kirmizi)}
        .rk-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:12px 13px}
        .rk-tile .n{font-size:22px;font-weight:800;color:var(--tx-0);line-height:1;font-variant-numeric:tabular-nums}.rk-tile .l{font-size:11px;color:var(--tx-1);margin-top:6px;font-weight:500}
        .rk-sec{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.06em;margin:20px 2px 10px;display:flex;justify-content:space-between;align-items:center}
        .rk-fil{display:flex;gap:4px}
        .rk-fil button{border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-family:inherit;font-size:11px;font-weight:700;padding:4px 11px;border-radius:999px;cursor:pointer;text-transform:none;letter-spacing:0}
        .rk-fil button.on{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}
        .rl{display:flex;flex-direction:column;gap:8px}
        .rl-row{display:grid;grid-template-columns:1fr 150px 130px;gap:14px;align-items:center;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:12px 15px 12px 14px;position:relative;overflow:hidden;cursor:pointer}
        .rl-row:hover{box-shadow:0 4px 14px rgba(0,0,0,.05)}
        .rl-sev{position:absolute;left:0;top:0;bottom:0;width:4px}.rl-sev.hot{background:var(--kirmizi)}.rl-sev.warm{background:var(--sari)}.rl-sev.ok{background:var(--yesil)}
        .rl-firm{font-size:14px;font-weight:700;color:var(--tx-0);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .rl-meta{font-size:11.5px;color:var(--tx-2);margin-top:3px;display:flex;gap:9px;flex-wrap:wrap;align-items:center}.rl-rep{color:var(--tx-1);font-weight:600}
        .rl-lim{font-size:9.5px;font-weight:800;color:var(--kirmizi);background:var(--kirmizi-z);padding:1px 6px;border-radius:999px}
        .rl-visit .v{font-size:12.5px;font-weight:700;font-variant-numeric:tabular-nums}.rl-visit .v.cold{color:var(--kirmizi)}.rl-visit .v.warm{color:var(--sari)}.rl-visit .v.fresh{color:var(--yesil)}.rl-visit .k{font-size:10px;color:var(--tx-2)}
        .rl-amt{text-align:right}.rl-amt .v{font-size:19px;font-weight:800;color:var(--tx-0);font-variant-numeric:tabular-nums;line-height:1}.rl-amt .k{font-size:10px;color:var(--tx-2);margin-top:3px}
        .rr{display:flex;flex-direction:column;gap:9px}
        .rr-row{display:grid;grid-template-columns:1fr 170px 120px;gap:16px;align-items:center;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:13px 15px}
        .rr-nm{font-size:14px;font-weight:700;color:var(--tx-0)}.rr-sub{font-size:11.5px;color:var(--tx-2);margin-top:4px}.rr-sub b{color:var(--tx-1)}
        .rr-bar .bl{display:flex;justify-content:space-between;font-size:10px;color:var(--tx-2);font-weight:600;margin-bottom:3px}.rr-bar .bl b{color:var(--kirmizi);font-variant-numeric:tabular-nums}
        .rr-track{height:7px;border-radius:999px;background:var(--zemin-2);overflow:hidden}.rr-fill{height:100%;border-radius:999px;background:linear-gradient(90deg,#C43D28,#e5734f)}
        .rr-amt{text-align:right;font-size:17px;font-weight:800;color:var(--tx-0);font-variant-numeric:tabular-nums}
        .rk-lgnd{display:flex;gap:14px;font-size:11px;color:var(--tx-2);font-weight:600}.rk-lgnd i{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:5px;vertical-align:middle}
        .rk-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}
      </style>`;
      const INTRO = `<div class="rk-intro"><h3>🚨 Risk Radarı — ne işe yarar?</h3>
        <p>Vadesi geçmiş alacağı olan müşterileri <b>ziyaret güncelliğiyle</b> çaprazlar. Asıl tehlike: <b>parası gecikmiş ama kimsenin uğramadığı "soğuk" müşteriler</b>. Liste yukarıdan aşağı kapatılır — önce en çok gecikmiş + en uzun ihmal. (Yalnız ERP'ye bağlı müşteride gecikmiş görünür → eşleştirmeyi de teşvik eder.)</p>
        <div class="calc">
          <div><b>Gecikmiş</b> = <code>bi_musteri_risk.vadesi_gecmis</code> (FIFO; SAP alacak yaşlandırma). Eşleşme <code>musteri_kodu</code> ile.</div>
          <div><b>Son ziyaret</b> = en son tamamlanmış ziyaret (paylaşımlı havuz).</div>
          <div><b>🥶 Soğuk gecikmiş</b> = gecikmiş + 30+ gündür ya da hiç ziyaret edilmemiş — en acil kova.</div>
          <div><b>Öncelik</b> = önce soğuk, sonra tutara göre azalan. <b>Limit aşımı</b> = <code>limit_asimi &gt; 0</code>.</div>
        </div></div>`;
      const ms = d.musteriler || [];
      const rows = (arr) => arr.slice().sort((a, b) => { const sa = sev(a.gun) === "hot" ? 1 : 0, sb = sev(b.gun) === "hot" ? 1 : 0; if (sa !== sb) return sb - sa; return (b.overdue || 0) - (a.overdue || 0); })
        .map(m => { const sv = sev(m.gun), [vl, vc] = visLbl(m.gun), al = repAlan(m.saha_tip);
          return `<div class="rl-row" data-mid="${esc(m.id)}"><div class="rl-sev ${sv}"></div>
            <div style="min-width:0"><div class="rl-firm">${esc(m.firma)}</div><div class="rl-meta"><span class="rl-rep">${esc(m.rep || "—")}</span><span>· ${al ? ALAN[al].ad : "—"}</span>${m.limit ? `<span class="rl-lim">Limit aşımı</span>` : ""}</div></div>
            <div class="rl-visit"><span class="v ${vc}">${vl}</span><span class="k">son ziyaret</span></div>
            <div class="rl-amt"><div class="v">${kisa(m.overdue)}</div><div class="k">gecikmiş</div></div></div>`; }).join("");
      const tiles = (arr, etiket) => { const tp = arr.reduce((s, m) => s + (m.overdue || 0), 0), sg = arr.filter(m => m.gun === null || m.gun > 30).reduce((s, m) => s + (m.overdue || 0), 0), lm = arr.filter(m => m.limit).length;
        return `<div class="rk-grid">
          <div class="rk-hero al"><div class="l">Toplam gecikmiş · ${etiket}</div><div class="n">${kisa(tp)}</div></div>
          <div class="rk-tile"><div class="n" style="color:var(--kirmizi)">${kisa(sg)}</div><div class="l">🥶 Soğuk gecikmiş (ziyaretsiz / +30g)</div></div>
          <div class="rk-tile"><div class="n">${arr.length}</div><div class="l">Riskli müşteri</div></div>
          <div class="rk-tile"><div class="n">${lm}</div><div class="l">Limit aşan</div></div></div>`; };
      const lgnd = `<span class="rk-lgnd"><span><i style="background:#C43D28"></i>Soğuk</span><span><i style="background:#8A5D06"></i>İzle</span><span><i style="background:#106B4A"></i>Taze</span></span>`;

      const bindRows = () => box.querySelectorAll(".rl-row[data-mid]").forEach(rw => rw.addEventListener("click", async () => {
        const id = rw.dataset.mid; let c = (S.musteriler || []).find(x => x.id === id);
        if (!c) { try { const res = await api(`/api/saha/musteriler/${id}`); c = res.musteri || res; } catch (e) {} }
        if (c) musteriDetay(c);
      }));
      if (d.rol === "rep") {
        box.innerHTML = CSS + `<div class="rk">${INTRO}${tiles(ms, "portföyün")}
          <div class="rk-sec"><span>🚨 Kritik müşterilerin · gecikmiş × ihmal</span>${lgnd}</div>
          ${ms.length ? `<div class="rl">${rows(ms)}</div>` : `<div class="rk-empty">Gecikmiş alacaklı müşterin yok. 👍</div>`}</div>`;
        bindRows();
      } else {
        const render = (field) => {
          const F = ms.filter(m => !field || repAlan(m.saha_tip) === field);
          const RR = {}; F.forEach(m => { const r = RR[m.rep_id] || (RR[m.rep_id] = { rep: m.rep, alan: repAlan(m.saha_tip), overdue: 0, cold: 0, n: 0 }); r.overdue += m.overdue || 0; r.n++; if (m.gun === null || m.gun > 30) r.cold += m.overdue || 0; });
          const rrArr = Object.values(RR).sort((a, b) => b.cold - a.cold); const maxCold = Math.max(...rrArr.map(r => r.cold), 1);
          const rrRows = rrArr.map(r => `<div class="rr-row"><div><div class="rr-nm">${esc(r.rep || "—")} <span style="font-size:10px;font-weight:700;color:var(--tx-2)">· ${r.alan ? ALAN[r.alan].ad : "—"}</span></div><div class="rr-sub"><b>${r.n}</b> riskli müşteri</div></div>
            <div class="rr-bar"><div class="bl"><span>Soğuk (ziyaretsiz) gecikmiş</span><b>${kisa(r.cold)}</b></div><div class="rr-track"><div class="rr-fill" style="width:${Math.max(3, Math.round(r.cold / maxCold * 100))}%"></div></div></div>
            <div class="rr-amt">${kisa(r.overdue)}<div style="font-size:10px;color:var(--tx-2);font-weight:600;margin-top:3px">toplam gecikmiş</div></div></div>`).join("") || `<div class="rk-empty">Bu sahada riskli müşteri yok.</div>`;
          const fb = (f, l) => `<button data-f="${f}" class="${field === f ? "on" : ""}">${l}</button>`;
          box.innerHTML = CSS + `<div class="rk">${INTRO}${tiles(F, field ? ALAN[field].ad + " saha" : "portföy")}
            <div class="rk-sec"><span>🚨 Kritik müşteriler · gecikmiş × ihmal</span><div class="rk-fil" id="rk-fil">${fb("", "Tümü")}${fb("TICARI", "Ticari")}${fb("TUKETICI", "Tüketici")}</div></div>
            <div style="margin:-4px 2px 8px">${lgnd}</div>
            ${F.length ? `<div class="rl">${rows(F)}</div>` : `<div class="rk-empty">Bu sahada gecikmiş alacaklı müşteri yok.</div>`}
            <div class="rk-sec"><span>Temsilci bazında risk · soğuk paraya göre</span></div>
            <div class="rr">${rrRows}</div></div>`;
          const fil = box.querySelector("#rk-fil"); if (fil) fil.querySelectorAll("button").forEach(b => b.addEventListener("click", () => render(b.dataset.f)));
          bindRows();
        };
        render("");
      }
    } catch (e) { const box = icerik(); if (box) box.innerHTML = hataH(e); }
  }
  async function rpCiro() {'''
assert s.count(anchor) == 1, "rpCiro anchor=%d" % s.count(anchor)
s = s.replace(anchor, RP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RISK_SAHA_DK_V1 (masaüstü)")
