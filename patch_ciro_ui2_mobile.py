# -*- coding: utf-8 -*-
# CIRO_UI2_V1 (mobil) — 💰 Ciro sekmesini YENIDEN yaz: app teması (açık token'lar, koyu-modda da açık),
#   taranabilir bölümlü düzen (cirolu / eşleşmemiş), eşleşmemiş satıra DOKUN → musteriDetayModal ile eşleştir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "CIRO_UI2_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

start = s.index("  async function rpCiro() {")
end = s.index("  async function rpTemsilciler() {")
assert start != -1 and end != -1 and end > start, "rpCiro sınırları bulunamadı"

NEW = r'''  async function rpCiro() {  /* CIRO_UI2_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const d = await api(`/api/saha/rapor/ziyaret-ciro?from=${rpFrom()}&to=${rpTo()}${tipQS()}`);
      const el2 = icerik(); if (!el2) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const CSS = `<style>
        .zc{padding:10px 12px 90px;color:var(--tx-0,#16161A)}
        .zc-hero{background:var(--zemin-1,#fff);border:1px solid var(--cizgi,rgba(0,0,0,.09));border-radius:16px;padding:16px;box-shadow:0 1px 2px rgba(0,0,0,.05)}
        .zc-hero .l{font-size:12px;font-weight:600;color:var(--tx-1,#5F5F66)}
        .zc-hero .n{font-size:34px;font-weight:800;letter-spacing:-.02em;color:var(--tx-0,#16161A);margin-top:2px}
        .zc-hero .n small{font-size:13px;color:var(--tx-2,#85858C);font-weight:600}
        .zc-grid{display:grid;gap:8px;margin-top:10px}
        .zc-g3{grid-template-columns:repeat(3,1fr)}.zc-g2{grid-template-columns:repeat(2,1fr)}
        .zc-tile{background:var(--zemin-1,#fff);border:1px solid var(--cizgi,rgba(0,0,0,.09));border-radius:12px;padding:10px 11px}
        .zc-tile .n{font-size:19px;font-weight:800;color:var(--tx-0,#16161A);line-height:1}
        .zc-tile .l{font-size:10.5px;color:var(--tx-1,#5F5F66);margin-top:5px;font-weight:500}
        .zc-match{background:var(--sari-z,#FEF6E7);border:1px solid rgba(138,93,6,.25);border-radius:12px;padding:12px;margin-top:12px}
        .zc-match .t{font-size:13px;font-weight:800;color:var(--sari,#8A5D06)}
        .zc-match .s{font-size:12px;color:var(--sari,#8A5D06);margin-top:4px;line-height:1.5}
        .zc-sec{font-size:11px;font-weight:800;color:var(--tx-1,#5F5F66);text-transform:uppercase;letter-spacing:.05em;margin:18px 2px 8px;display:flex;justify-content:space-between}
        .zc-card{background:var(--zemin-1,#fff);border:1px solid var(--cizgi,rgba(0,0,0,.09));border-radius:14px;overflow:hidden}
        .zc-row{display:flex;align-items:center;gap:10px;padding:11px 13px;border-bottom:1px solid var(--cizgi,rgba(0,0,0,.07))}
        .zc-row:last-child{border-bottom:0}
        .zc-row.tik{cursor:pointer}.zc-row.tik:active{background:var(--zemin-2,#F4F4F2)}
        .zc-row .f{flex:1;min-width:0}
        .zc-row .fn{font-size:13px;font-weight:600;color:var(--tx-0,#16161A);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .zc-row .fs{font-size:11px;color:var(--tx-2,#85858C);margin-top:1px}
        .zc-amt{font-size:13px;font-weight:700;color:var(--tx-0,#16161A);white-space:nowrap}
        .zc-go{color:var(--mavi,#0284c7);font-size:12px;font-weight:700;white-space:nowrap}
        .zc-daha{width:100%;border:0;background:var(--zemin-2,#F4F4F2);color:var(--tx-1,#5F5F66);font-family:inherit;font-size:12px;font-weight:700;padding:11px;cursor:pointer}
        .zc-empty{color:var(--tx-2,#85858C);text-align:center;padding:16px;font-size:12px}
      </style>`;
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

      if (d.rol === "rep") {
        const o = d.ozet || {}, ms = d.musteriler || [];
        const cirolu = ms.filter(m => m.musteri_kodu);
        const eslesmemis = ms.filter(m => !m.musteri_kodu).sort((a, b) => (b.ziyaret || 0) - (a.ziyaret || 0));
        el2.innerHTML = CSS + `<!--CIRO_UI2_V1--><div class="zc">
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
        const R = d.repler || [];
        el2.innerHTML = CSS + `<!--CIRO_UI2_V1--><div class="zc">
          <div class="zc-sec"><span>Ekip · Ziyaret → Ciro</span><span style="color:var(--tx-2)">${R.length} temsilci</span></div>
          <div class="zc-card">${R.length ? R.map(r => `
            <div class="zc-row"><div class="f"><div class="fn">${esc(r.rep)}</div><div class="fs">${r.ziyaret} ziyaret · ${r.benzersiz} müşteri${r.eslesen < r.benzersiz ? ` · <span style="color:var(--kirmizi,#C43D28)">${r.eslesen}/${r.benzersiz} eşleşti</span>` : ""} · kapsam ${r.kapsam != null ? "%" + r.kapsam : "—"}</div></div>
              <div style="text-align:right"><div class="zc-amt">${kisa(r.ciro)}</div><div class="fs">${kisa(r.ciro_ziyaret)}/ziy.</div></div></div>`).join("") : `<div class="zc-empty">Bu dönemde ziyaret yok.</div>`}</div>
          <div class="zc-match" style="margin-top:12px"><div class="t">Eşleşme etkiyi gizliyor olabilir</div><div class="s">"X/Y eşleşti" olan temsilcilerde bazı müşteriler ERP'ye bağlı değil — etki ciroları düşük görünür.</div></div>
        </div>`;
      }
      // "daha" genişlet
      el2.querySelectorAll(".zc-daha").forEach(b => b.addEventListener("click", () => {
        const card = document.getElementById("zc-" + b.dataset.k); if (!card) return;
        card.querySelectorAll("[data-extra]").forEach(x => x.style.display = "flex");
        b.style.display = "none";
      }));
      // eşleşmemiş satıra dokun → müşteri kartı (VKN gir → ERP eşleştir)
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
print("[done] CIRO_UI2_V1 (mobil)")
