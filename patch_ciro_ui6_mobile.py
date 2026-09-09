# -*- coding: utf-8 -*-
# CIRO_UI6_V1 (mobil) — yönetici Ciro'yu masaüstü UI6 ile eşitle: özet + saha kırılımı (Ticari/Tüketici) +
#   rep ₺/ziyaret'in saha ortalamasıyla karşılaştırması + rep-alanı seçici (Tümü/Ticari/Tüketici),
#   dar ekrana göre YIĞILMIŞ kartlar. Rep görünümü CIRO_UI2 gibi (açık, bölümlü, dokun-eşleştir) korunur.
#   Server zaten saha_tip + ziyaret kırılımı döndürüyor (CIRO_SEG_SRV_V1). rpCiro'yu tümüyle yeniden yazar.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "CIRO_UI6_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

start = s.find("  async function rpCiro() {")
end = s.find("  async function rpTemsilciler() {")
assert start != -1, "rpCiro bulunamadi — once mobil Ciro (ZIYARET_CIRO_UI_V1/CIRO_UI2_V1) olmali"
assert end != -1 and end > start, "rpTemsilciler sinir bulunamadi"

NEW = r'''  async function rpCiro() {  /* CIRO_UI6_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const d = await api(`/api/saha/rapor/ziyaret-ciro?from=${rpFrom()}&to=${rpTo()}${tipQS()}`);
      const el2 = icerik(); if (!el2) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const CSS = `<style>
        .zc{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#0284c7;color-scheme:light;padding:10px 12px 90px;color:var(--tx-0)}
        .zc *{box-sizing:border-box}
        .zc-hero{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:16px;padding:15px;box-shadow:0 1px 2px rgba(0,0,0,.05)}
        .zc-hero .l{font-size:12px;font-weight:600;color:var(--tx-1)}
        .zc-hero .n{font-size:31px;font-weight:800;letter-spacing:-.02em;color:var(--tx-0);margin-top:2px;font-variant-numeric:tabular-nums}
        .zc-hero .n small{font-size:13px;color:var(--tx-2);font-weight:600}
        .zc-grid{display:grid;gap:8px;margin-top:10px}
        .zc-g3{grid-template-columns:repeat(3,1fr)}.zc-g2{grid-template-columns:repeat(2,1fr)}
        .zc-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:10px 11px}
        .zc-tile .n{font-size:19px;font-weight:800;color:var(--tx-0);line-height:1;font-variant-numeric:tabular-nums}
        .zc-tile .l{font-size:10.5px;color:var(--tx-1);margin-top:5px;font-weight:500}
        .zc-match{background:var(--sari-z);border:1px solid rgba(138,93,6,.25);border-radius:12px;padding:12px;margin-top:12px}
        .zc-match .t{font-size:13px;font-weight:800;color:var(--sari)}
        .zc-match .s{font-size:12px;color:var(--sari);margin-top:4px;line-height:1.5}
        .zc-sec{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.05em;margin:18px 2px 8px;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap}
        .zc-fil{display:flex;gap:4px}
        .zc-fil button{border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-family:inherit;font-size:11px;font-weight:700;padding:4px 10px;border-radius:999px;cursor:pointer;text-transform:none;letter-spacing:0}
        .zc-fil button.on{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}
        .zc-card{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;overflow:hidden}
        .zc-row{display:flex;align-items:center;gap:10px;padding:11px 13px;border-bottom:1px solid var(--cizgi)}
        .zc-row:last-child{border-bottom:0}
        .zc-row.tik:active{background:var(--zemin-2)}
        .zc-row .f{flex:1;min-width:0}.zc-row .fn{font-size:13px;font-weight:600;color:var(--tx-0);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.zc-row .fs{font-size:11px;color:var(--tx-2);margin-top:1px}
        .zc-amt{font-size:13px;font-weight:700;color:var(--tx-0);white-space:nowrap}
        .zc-go{color:var(--mavi);font-size:12px;font-weight:700;white-space:nowrap}
        .zc-daha{width:100%;border:0;background:var(--zemin-2);color:var(--tx-1);font-family:inherit;font-size:12px;font-weight:700;padding:11px;cursor:pointer}
        .zc-empty{color:var(--tx-2);text-align:center;padding:18px;font-size:12px}
        /* saha kırılımı */
        .zc-fcard{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:13px 14px;position:relative;overflow:hidden;margin-top:8px}
        .zc-fcard:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--fc)}
        .zc-fhead{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:800;color:var(--tx-0);margin-bottom:11px}
        .zc-fdot{width:9px;height:9px;border-radius:3px;background:var(--fc)}.zc-fhead .c{margin-left:auto;font-size:10.5px;font-weight:700;color:var(--tx-2)}
        .zc-fmini{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}
        .zc-fmini .n{font-size:16px;font-weight:800;color:var(--tx-0);line-height:1;font-variant-numeric:tabular-nums}.zc-fmini .l{font-size:9.5px;color:var(--tx-1);margin-top:4px;font-weight:500}
        /* leaderboard (mobil yığılmış) */
        .mlb{display:flex;flex-direction:column;gap:9px}
        .mlb-row{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:12px 13px}
        .mlb-row.top1{border-color:rgba(184,134,11,.4)}
        .mlb-top{display:flex;align-items:center;gap:9px}
        .mlb-rank{font-size:13px;font-weight:800;color:var(--tx-3);min-width:16px;text-align:center;font-variant-numeric:tabular-nums}
        .mlb-row.top1 .mlb-rank{color:#B8860B}.mlb-row.top2 .mlb-rank{color:#8a8a95}.mlb-row.top3 .mlb-rank{color:#a9744f}
        .mlb-nm{flex:1;min-width:0;font-size:14px;font-weight:700;color:var(--tx-0);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:flex;align-items:center;gap:6px}
        .mlb-seg{font-size:9px;font-weight:800;padding:1px 6px;border-radius:999px;white-space:nowrap}
        .mlb-amt{text-align:right;white-space:nowrap}.mlb-amt .v{font-size:17px;font-weight:800;color:var(--tx-0);font-variant-numeric:tabular-nums;line-height:1}.mlb-amt .k{font-size:9.5px;color:var(--tx-2);margin-top:2px}
        .mlb-sub{display:flex;gap:11px;flex-wrap:wrap;margin-top:9px;font-size:11.5px;color:var(--tx-1);align-items:center}
        .mlb-sub b{color:var(--tx-0);font-weight:700;font-variant-numeric:tabular-nums}
        .mlb-cmp{font-size:10.5px;font-weight:800;padding:1px 5px;border-radius:999px;margin-left:4px;font-variant-numeric:tabular-nums}
        .mlb-cmp.up{color:var(--yesil);background:var(--yesil-z)}.mlb-cmp.down{color:var(--kirmizi);background:var(--kirmizi-z)}
        .mlb-bars{margin-top:9px;display:grid;grid-template-columns:1fr 1fr;gap:7px 14px}
        .mlb-bar .bl{display:flex;justify-content:space-between;font-size:10px;color:var(--tx-2);font-weight:600;margin-bottom:3px}.mlb-bar .bl b{color:var(--tx-1);font-variant-numeric:tabular-nums}
        .mlb-track{height:6px;border-radius:999px;background:var(--zemin-2);overflow:hidden}.mlb-fill{height:100%;border-radius:999px}
        .mlb-fill.ciro{background:linear-gradient(90deg,#2563eb,#3b82f6)}.mlb-fill.kaps{background:linear-gradient(90deg,#106B4A,#12b981)}.mlb-fill.kaps.dus{background:linear-gradient(90deg,#C43D28,#e5734f)}
        .mlb-lock{margin-top:9px;display:inline-flex;align-items:center;gap:5px;background:var(--sari-z);border:1px solid rgba(138,93,6,.22);color:var(--sari);font-size:11px;font-weight:700;padding:4px 8px;border-radius:999px}
      </style>`;
      const repAlan = (r) => {
        const a = String(r.saha_tip || "").toUpperCase();
        if (a === "TUKETICI") return "TUKETICI";
        if (a === "TICARI") return "TICARI";
        const tk = Number(r.tuketici_z) || 0, tc = Number(r.ticari_z) || 0;
        if (!tk && !tc) return null;
        return tk >= tc ? "TUKETICI" : "TICARI";
      };
      const ALAN = { TICARI: { ad: "Ticari", c: "#f59e0b" }, TUKETICI: { ad: "Tüketici", c: "#0ea5e9" } };
      if (d.rol === "rep") {
        const o = d.ozet || {}, ms = d.musteriler || [];
        const cirolu = ms.filter(m => m.musteri_kodu);
        const eslesmemis = ms.filter(m => !m.musteri_kodu).sort((a, b) => (b.ziyaret || 0) - (a.ziyaret || 0));
        const rowsHtml = (arr, tik) => arr.map((m, i) => `
          <div class="zc-row${tik ? " tik" : ""}" ${tik ? `data-mid="${esc(m.id)}"` : ""} ${i >= 12 ? `data-extra="1" style="display:none"` : ""}>
            <div class="f"><div class="fn">${esc(m.firma)}</div><div class="fs">${m.ziyaret} ziyaret${m.tip === "TICARI" ? " · Ticari" : m.tip === "TUKETICI" ? " · Tüketici" : ""}</div></div>
            ${tik ? `<span class="zc-go">eşleştir ›</span>` : `<span class="zc-amt">${kisa(m.ciro)}</span>`}
          </div>`).join("");
        const section = (baslik, sag, arr, tik, idkey) => {
          if (!arr.length) return "";
          const extra = arr.length - 12;
          return `<div class="zc-sec"><span>${baslik}</span><span style="color:var(--tx-2)">${sag}</span></div>
            <div class="zc-card" id="zc-${idkey}">${rowsHtml(arr, tik)}${extra > 0 ? `<button class="zc-daha" data-k="${idkey}">+ ${extra} tane daha</button>` : ""}</div>`;
        };
        el2.innerHTML = CSS + `<!--CIRO_UI6_V1--><div class="zc">
          <div class="zc-hero"><div class="l">Ziyaret başına ciro · dönem</div><div class="n">${kisa(o.ciro_ziyaret)}<small>/ziyaret</small></div></div>
          <div class="zc-grid zc-g3">
            <div class="zc-tile"><div class="n">${o.ziyaret || 0}</div><div class="l">Ziyaret</div></div>
            <div class="zc-tile"><div class="n">${o.benzersiz || 0}</div><div class="l">Ulaşılan</div></div>
            <div class="zc-tile"><div class="n">${o.donusum != null ? "%" + o.donusum : "—"}</div><div class="l">Dönüşüm</div></div>
          </div>
          <div class="zc-grid zc-g2">
            <div class="zc-tile"><div class="n">${kisa(o.ciro)}</div><div class="l">Toplam ERP ciro</div></div>
            <div class="zc-tile"><div class="n">${o.eslesen || 0}<span style="font-size:12px;color:var(--tx-3)"> / ${o.benzersiz || 0}</span></div><div class="l">ERP'ye bağlı</div></div>
          </div>
          ${o.eslesmemis > 0 ? `<div class="zc-match"><div class="t">🔗 ${o.eslesmemis} müşterin ERP'ye bağlı değil</div><div class="s">Aşağıdaki listede müşteriye <b>dokun → eşleştir</b>. Bağladıkça gerçek ziyaret-başına-ciron görünür.</div></div>` : ""}
          ${section("💰 Cirolu müşteriler", cirolu.length + "", cirolu, false, "cir")}
          ${section("🔗 Eşleştir — dokun", eslesmemis.length + " müşteri", eslesmemis, true, "esl")}
          ${!ms.length ? `<div class="zc-empty">Bu dönemde ziyaret yok.</div>` : ""}
        </div>`;
      } else {
        const R = (d.repler || []).slice().sort((a, b) => (Number(b.ciro) || 0) - (Number(a.ciro) || 0));
        const toplamCiro = R.reduce((s, r) => s + (Number(r.ciro) || 0), 0);
        const toplamZiy = R.reduce((s, r) => s + (Number(r.ziyaret) || 0), 0);
        const maxCiro = R.reduce((m, r) => Math.max(m, Number(r.ciro) || 0), 0) || 1;
        const toplamEsl = R.reduce((s, r) => s + (Number(r.eslesen) || 0), 0);
        const toplamBenz = R.reduce((s, r) => s + (Number(r.benzersiz) || 0), 0);
        const ortKapsam = toplamBenz ? Math.round(toplamEsl / toplamBenz * 100) : null;
        const ekipCiroZiy = toplamZiy ? toplamCiro / toplamZiy : 0;
        const acikRep = R.filter(r => (r.eslesen != null && r.benzersiz != null && r.eslesen < r.benzersiz)).length;
        const G = { TICARI: { ciro: 0, ziy: 0, esl: 0, benz: 0, n: 0 }, TUKETICI: { ciro: 0, ziy: 0, esl: 0, benz: 0, n: 0 } };
        R.forEach(r => { const f = repAlan(r); if (!f || !G[f]) return; const g = G[f]; g.ciro += Number(r.ciro) || 0; g.ziy += Number(r.ziyaret) || 0; g.esl += Number(r.eslesen) || 0; g.benz += Number(r.benzersiz) || 0; g.n++; });
        const fBench = (f) => (f && G[f] && G[f].ziy) ? G[f].ciro / G[f].ziy : 0;
        const splitHtml = ["TICARI", "TUKETICI"].map(k => {
          const g = G[k], meta = ALAN[k];
          const cz = g.ziy ? g.ciro / g.ziy : 0, kp = g.benz ? Math.round(g.esl / g.benz * 100) : null;
          return `<div class="zc-fcard" style="--fc:${meta.c}">
            <div class="zc-fhead"><span class="zc-fdot"></span>${meta.ad} saha<span class="c">${g.n} temsilci</span></div>
            <div class="zc-fmini"><div><div class="n">${kisa(g.ciro)}</div><div class="l">Etki ciro</div></div><div><div class="n">${kisa(cz)}</div><div class="l">₺/ziy.</div></div><div><div class="n">${kp != null ? "%" + kp : "—"}</div><div class="l">Kapsam</div></div><div><div class="n">${g.n}</div><div class="l">Temsilci</div></div></div>
          </div>`;
        }).join("");
        const rows = R.map((r, i) => {
          const ciro = Number(r.ciro) || 0;
          const pay = Math.max(2, Math.round(ciro / maxCiro * 100));
          const kaps = (r.benzersiz && Number(r.benzersiz) > 0) ? Math.round((Number(r.eslesen) || 0) / Number(r.benzersiz) * 100) : null;
          const acik = (r.eslesen != null && r.benzersiz != null) ? (r.benzersiz - r.eslesen) : 0;
          const f = repAlan(r), meta = f ? ALAN[f] : null;
          const seg = meta ? `<span class="mlb-seg" style="color:${meta.c};background:${meta.c}1f">${meta.ad}</span>` : "";
          const rz = Number(r.ciro_ziyaret) || 0, bench = fBench(f);
          let cmp = "";
          if (bench > 0 && rz > 0) { const dp = Math.round((rz - bench) / bench * 100); cmp = `<span class="mlb-cmp ${dp >= 0 ? "up" : "down"}">${dp >= 0 ? "▲" : "▼"} %${Math.abs(dp)}</span>`; }
          return `<div class="mlb-row" data-field="${f || ""}">
            <div class="mlb-top"><div class="mlb-rank">${i + 1}</div><div class="mlb-nm">${esc(r.rep)}${seg}</div><div class="mlb-amt"><div class="v">${kisa(ciro)}</div><div class="k">etki ciro</div></div></div>
            <div class="mlb-sub"><span>Ziyaret <b>${r.ziyaret || 0}</b></span><span>Ulaşılan <b>${r.benzersiz || 0}</b></span><span>Dönüşüm <b>${r.donusum != null ? "%" + r.donusum : "—"}</b></span><span>₺/ziy. <b>${kisa(r.ciro_ziyaret)}</b>${cmp}</span></div>
            <div class="mlb-bars">
              <div class="mlb-bar"><div class="bl"><span>Ciro payı</span><b>${toplamCiro ? Math.round(ciro / toplamCiro * 100) : 0}%</b></div><div class="mlb-track"><div class="mlb-fill ciro" style="width:${pay}%"></div></div></div>
              <div class="mlb-bar"><div class="bl"><span>ERP kapsamı</span><b>${kaps != null ? "%" + kaps : "—"}</b></div><div class="mlb-track"><div class="mlb-fill kaps${kaps != null && kaps < 60 ? " dus" : ""}" style="width:${kaps != null ? Math.max(2, kaps) : 0}%"></div></div></div>
            </div>
            ${acik > 0 ? `<div class="mlb-lock">🔒 ${acik} müşteri bağlanınca ciro açılır</div>` : ""}
          </div>`;
        }).join("");
        el2.innerHTML = CSS + `<!--CIRO_UI6_V1--><div class="zc">
          <div class="zc-hero"><div class="l">Toplam etki ciro · dönem</div><div class="n">${kisa(toplamCiro)}</div></div>
          <div class="zc-grid zc-g3">
            <div class="zc-tile"><div class="n">${kisa(ekipCiroZiy)}</div><div class="l">Ekip ₺/ziy.</div></div>
            <div class="zc-tile"><div class="n">${ortKapsam != null ? "%" + ortKapsam : "—"}</div><div class="l">Ort. kapsam</div></div>
            <div class="zc-tile"><div class="n">${R.length}</div><div class="l">Temsilci</div></div>
          </div>
          <div class="zc-sec"><span>Saha kırılımı</span></div>
          ${splitHtml}
          <div class="zc-sec"><span>Ekip sıralaması <span id="zc-say" style="color:var(--tx-2)">· ${R.length}</span></span>
            <div class="zc-fil" id="zc-fil"><button data-f="" class="on">Tümü</button><button data-f="TICARI">Ticari</button><button data-f="TUKETICI">Tüketici</button></div>
          </div>
          ${R.length ? `<div class="mlb">${rows}</div>` : `<div class="zc-empty">Bu dönemde ziyaret yok.</div>`}
          ${acikRep > 0 ? `<div class="zc-match" style="margin-top:12px"><div class="t">🔒 ${acikRep} temsilcide kilitli ciro var</div><div class="s">Bazı ziyaret edilen müşteriler ERP'ye bağlı değil — o ciro burada görünmüyor. Eşleştirme arttıkça sıralama netleşir.</div></div>` : ""}
        </div>`;
        const fil = el2.querySelector("#zc-fil"), say = el2.querySelector("#zc-say");
        if (fil) fil.querySelectorAll("button").forEach(b => b.addEventListener("click", () => {
          const f = b.dataset.f;
          fil.querySelectorAll("button").forEach(x => x.classList.toggle("on", x === b));
          let rank = 0;
          el2.querySelectorAll(".mlb-row").forEach(row => {
            const show = !f || row.dataset.field === f;
            row.style.display = show ? "" : "none";
            row.classList.remove("top1", "top2", "top3");
            if (show) { rank++; const rk = row.querySelector(".mlb-rank"); if (rk) rk.textContent = rank; if (rank <= 3) row.classList.add("top" + rank); }
          });
          if (say) say.textContent = "· " + rank;
        }));
      }
      el2.querySelectorAll(".zc-daha").forEach(b => b.addEventListener("click", () => {
        const card = document.getElementById("zc-" + b.dataset.k); if (!card) return;
        card.querySelectorAll("[data-extra]").forEach(x => x.style.display = "flex"); b.style.display = "none";
      }));
      el2.querySelectorAll(".zc-row.tik[data-mid]").forEach(r => r.addEventListener("click", async () => {
        const id = r.dataset.mid;
        let c = (S.musteriler || []).find(x => x.id === id);
        if (!c) { try { const res = await api(`/api/saha/musteriler/${id}`); c = res.musteri || res; } catch (e) {} }
        if (c) musteriDetayModal(c);
      }));
    } catch (e) { const el2 = icerik(); if (el2) el2.innerHTML = hata(e); }
  }
  '''
s = s[:start] + NEW + s[end:]
open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_UI6_V1 (mobil) — kırılım + karşılaştırma + seçici")
