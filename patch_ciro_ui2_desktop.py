# -*- coding: utf-8 -*-
# CIRO_UI2_DK_V1 (masaüstü) — 💰 Ciro sekmesi (app token'ları/açık tema; ekip matrisi + rep bölümlü + dokun-eşleştir).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "CIRO_UI2_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) sekme
t_old = '    ["ozet", "📊 Özet"],'
t_new = '    ["ozet", "📊 Özet"],\n    ["ciro", "💰 Ciro"],  /* CIRO_UI2_DK_V1 */'
assert s.count(t_old) == 1, "tab anchor=%d" % s.count(t_old)
s = s.replace(t_old, t_new, 1)

# 2) RENDER map
m_old = 'const RENDER = { ozet: rpOzet, temsilciler: rpTemsilciler, pipeline: rpPipeline, pazar: rpPazar };'
m_new = 'const RENDER = { ozet: rpOzet, ciro: rpCiro, temsilciler: rpTemsilciler, pipeline: rpPipeline, pazar: rpPazar };'
assert s.count(m_old) == 1, "render anchor=%d" % s.count(m_old)
s = s.replace(m_old, m_new, 1)

# 3) rpCiro fn
r_anchor = "  async function rpTemsilciler() {"
RP = r'''  async function rpCiro() {  /* CIRO_UI2_DK_V1 */
    const el = icerik(); if (!el) return; el.innerHTML = load();
    try {
      const d = await api(`/api/saha/rapor/ziyaret-ciro?from=${rpFrom()}&to=${rpTo()}${tipQS()}`);
      const el2 = icerik(); if (!el2) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const CSS = `<style>
        .zc{color:var(--tx-0,#16161A)}
        .zc-hero{background:var(--zemin-1,#fff);border:1px solid var(--cizgi,rgba(0,0,0,.09));border-radius:16px;padding:18px}
        .zc-hero .l{font-size:12px;font-weight:600;color:var(--tx-1,#5F5F66)}
        .zc-hero .n{font-size:38px;font-weight:800;letter-spacing:-.02em;color:var(--tx-0,#16161A);margin-top:2px}
        .zc-hero .n small{font-size:14px;color:var(--tx-2,#85858C);font-weight:600}
        .zc-grid{display:grid;gap:10px;margin-top:12px;grid-template-columns:repeat(5,1fr)}
        .zc-tile{background:var(--zemin-1,#fff);border:1px solid var(--cizgi,rgba(0,0,0,.09));border-radius:13px;padding:12px 13px}
        .zc-tile .n{font-size:22px;font-weight:800;color:var(--tx-0,#16161A);line-height:1}
        .zc-tile .l{font-size:11px;color:var(--tx-1,#5F5F66);margin-top:6px;font-weight:500}
        .zc-match{background:var(--sari-z,#FEF6E7);border:1px solid rgba(138,93,6,.25);border-radius:13px;padding:13px 15px;margin-top:12px}
        .zc-match .t{font-size:14px;font-weight:800;color:var(--sari,#8A5D06)}
        .zc-match .s{font-size:12.5px;color:var(--sari,#8A5D06);margin-top:4px;line-height:1.5}
        .zc-sec{font-size:11px;font-weight:800;color:var(--tx-1,#5F5F66);text-transform:uppercase;letter-spacing:.06em;margin:18px 2px 9px;display:flex;justify-content:space-between}
        .zc-card{background:var(--zemin-1,#fff);border:1px solid var(--cizgi,rgba(0,0,0,.09));border-radius:14px;overflow:hidden}
        table.zc-t{width:100%;border-collapse:collapse;font-size:13px}
        table.zc-t th{text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.04em;color:var(--tx-2,#85858C);font-weight:700;padding:9px 12px;border-bottom:1px solid var(--cizgi,rgba(0,0,0,.09))}
        table.zc-t td{padding:9px 12px;border-bottom:1px solid var(--cizgi,rgba(0,0,0,.06));color:var(--tx-0,#16161A)}
        table.zc-t tr:last-child td{border-bottom:0}
        table.zc-t td.num,table.zc-t th.num{text-align:right}
        table.zc-t tr.tik{cursor:pointer}table.zc-t tr.tik:hover td{background:var(--zemin-2,#F4F4F2)}
        .zc-x{font-size:9px;font-weight:800;color:var(--kirmizi,#C43D28);background:var(--kirmizi-z,#FDF0ED);padding:1px 6px;border-radius:999px;white-space:nowrap}
        .zc-go{color:var(--mavi,#2563eb);font-weight:700}
        .zc-daha{width:100%;border:0;background:var(--zemin-2,#F4F4F2);color:var(--tx-1,#5F5F66);font-family:inherit;font-size:12px;font-weight:700;padding:11px;cursor:pointer}
        .zc-empty{color:var(--tx-2,#85858C);text-align:center;padding:16px;font-size:12px}
      </style>`;
      if (d.rol === "rep") {
        const o = d.ozet || {}, ms = d.musteriler || [];
        const cirolu = ms.filter(m => m.musteri_kodu);
        const esl = ms.filter(m => !m.musteri_kodu).sort((a, b) => (b.ziyaret || 0) - (a.ziyaret || 0));
        const tbl = (arr, tik) => `<table class="zc-t"><tbody>${arr.map((m, i) => `<tr class="${tik ? "tik" : ""}" ${tik ? `data-mid="${esc(m.id)}"` : ""} ${i >= 12 ? `data-extra="1" style="display:none"` : ""}><td>${esc(m.firma)}</td><td class="num" style="color:var(--tx-2)">${m.ziyaret} ziyaret</td><td class="num">${tik ? `<span class="zc-go">eşleştir ›</span>` : kisa(m.ciro)}</td></tr>`).join("")}</tbody></table>`;
        const sec = (b, sag, arr, tik, k) => arr.length ? `<div class="zc-sec"><span>${b}</span><span style="color:var(--tx-2)">${sag}</span></div><div class="zc-card" id="zc-${k}">${tbl(arr, tik)}${arr.length > 12 ? `<button class="zc-daha" data-k="${k}">+ ${arr.length - 12} tane daha</button>` : ""}</div>` : "";
        el2.innerHTML = CSS + `<!--CIRO_UI2_DK_V1--><div class="zc">
          <div style="display:grid;grid-template-columns:1fr 2fr;gap:14px">
            <div class="zc-hero"><div class="l">Ziyaret başına ciro · dönem</div><div class="n">${kisa(o.ciro_ziyaret)}<small>/ziyaret</small></div></div>
            <div class="zc-grid" style="grid-template-columns:repeat(2,1fr);margin-top:0">
              <div class="zc-tile"><div class="n">${o.ziyaret || 0}</div><div class="l">Ziyaret</div></div>
              <div class="zc-tile"><div class="n">${o.benzersiz || 0}</div><div class="l">Ulaşılan</div></div>
              <div class="zc-tile"><div class="n">${kisa(o.ciro)}</div><div class="l">Toplam ERP ciro</div></div>
              <div class="zc-tile"><div class="n">${o.eslesen || 0}<span style="font-size:12px;color:var(--tx-3)"> / ${o.benzersiz || 0}</span></div><div class="l">ERP'ye bağlı</div></div>
            </div>
          </div>
          ${o.eslesmemis > 0 ? `<div class="zc-match"><div class="t">🔗 ${o.eslesmemis} müşterin ERP'ye bağlı değil</div><div class="s">Aşağıda müşteriye <b>tıkla → eşleştir</b>. Bağladıkça gerçek ciron görünür.</div></div>` : ""}
          ${sec("💰 Cirolu müşteriler", cirolu.length + "", cirolu, false, "cir")}
          ${sec("🔗 Eşleştir — tıkla", esl.length + " müşteri", esl, true, "esl")}
          ${!ms.length ? `<div class="zc-empty">Bu dönemde ziyaret yok.</div>` : ""}
        </div>`;
      } else {
        const R = d.repler || [];
        el2.innerHTML = CSS + `<!--CIRO_UI2_DK_V1--><div class="zc">
          <div class="zc-sec"><span>Ekip · Ziyaret → Ciro</span><span style="color:var(--tx-2)">${R.length} temsilci</span></div>
          <div class="zc-card"><table class="zc-t"><thead><tr><th>Temsilci</th><th class="num">Ziyaret</th><th class="num">Ulaşılan</th><th class="num">Kapsam</th><th class="num">Dönüşüm</th><th class="num">₺ / ziyaret</th><th class="num">Etki Ciro</th></tr></thead><tbody>
            ${R.length ? R.map(r => `<tr><td>${esc(r.rep)}${r.eslesen < r.benzersiz ? ` <span class="zc-x" title="${r.benzersiz - r.eslesen} müşteri ERP'ye bağlı değil">${r.eslesen}/${r.benzersiz}</span>` : ""}</td><td class="num">${r.ziyaret}</td><td class="num">${r.benzersiz}</td><td class="num">${r.kapsam != null ? "%" + r.kapsam : "—"}</td><td class="num">${r.donusum != null ? "%" + r.donusum : "—"}</td><td class="num">${kisa(r.ciro_ziyaret)}</td><td class="num" style="font-weight:800">${money(r.ciro)}</td></tr>`).join("") : `<tr><td colspan="7" class="zc-empty">Bu dönemde ziyaret yok.</td></tr>`}
          </tbody></table></div>
          <div class="zc-match" style="margin-top:14px"><div class="t">Eşleşme kapsamı etkiyi gizliyor olabilir</div><div class="s">"X/Y" işaretli temsilcilerde bazı müşteriler ERP'ye bağlı değil — etki ciroları düşük görünür. Eşleştirme arttıkça gerçek rakam yükselir.</div></div>
        </div>`;
      }
      el2.querySelectorAll(".zc-daha").forEach(b => b.addEventListener("click", () => {
        const card = document.getElementById("zc-" + b.dataset.k); if (!card) return;
        card.querySelectorAll("[data-extra]").forEach(x => x.style.display = "table-row"); b.style.display = "none";
      }));
      el2.querySelectorAll("tr.tik[data-mid]").forEach(r => r.addEventListener("click", async () => {
        const id = r.dataset.mid;
        let c = (S.musteriler || []).find(x => x.id === id);
        if (!c) { try { const res = await api(`/api/saha/musteriler/${id}`); c = res.musteri || res; } catch (e) {} }
        if (c) musteriDetay(c);
      }));
    } catch (e) { const el2 = icerik(); if (el2) el2.innerHTML = hataH(e); }
  }
  async function rpTemsilciler() {'''
assert s.count(r_anchor) == 1, "rpCiro anchor=%d" % s.count(r_anchor)
s = s.replace(r_anchor, RP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_UI2_DK_V1 (masaüstü)")
