# -*- coding: utf-8 -*-
# CIRO_UI3_DK_V1 (masaüstü) — Ciro sekmesini creative-agency seviyesine çıkar + koyu-tema kaçağını KESİN kapat.
#   1) Koyu-tema fix: açık token değerlerini doğrudan .zc'ye sabitle (SAHA_TEMA_FIX2 tekniği).
#      BI kabuğu <html data-tema="koyu"> → miras --zemin-1 KOYU; element üstündeki custom property EZER,
#      .zc'nin tüm altları (kart/tablo/hücre) açık çözülür. var(--x,#fff) fallback'e güvenmeyiz.
#   2) Yönetici görünümü: düz kırmızı X/Y matris YERİNE sıralı LEADERBOARD:
#      ciro-payı barı, kapsam barı, ₺/ziyaret, dönüşüm; ERP açığı "kilitli potansiyel" olarak çerçeveli
#      (başarısızlık gibi değil) → ERP eşleştirmeyi tamamlamaya iten forcing-function.
#   Yöntem: rpCiro'yu sınır-değiştirme ile TÜMÜYLE yeniden yaz (CIRO_UI2_DK'nin yerine geçer).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "CIRO_UI3_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

start = s.find("  async function rpCiro() {")
end = s.find("  async function rpTemsilciler() {")
assert start != -1, "rpCiro bulunamadi — once CIRO_UI2_DK deploy edilmeli"
assert end != -1 and end > start, "rpTemsilciler sinir bulunamadi"

NEW = r'''  async function rpCiro() {  /* CIRO_UI3_DK_V1 */
    const el = icerik(); if (!el) return; el.innerHTML = load();
    try {
      const d = await api(`/api/saha/rapor/ziyaret-ciro?from=${rpFrom()}&to=${rpTo()}${tipQS()}`);
      const el2 = icerik(); if (!el2) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const CSS = `<style>
        /* CIRO_UI3_DK_V1 — açık token'lar .zc'ye sabit (koyu kabukta bile açık kalır) */
        .zc{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--cizgi-g:rgba(0,0,0,.18);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#2563eb;color-scheme:light;color:var(--tx-0);font-family:var(--sans,-apple-system,'Segoe UI',system-ui,sans-serif)}
        .zc *{box-sizing:border-box}
        .zc-hero{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:16px;padding:18px}
        .zc-hero .l{font-size:12px;font-weight:600;color:var(--tx-1)}
        .zc-hero .n{font-size:38px;font-weight:800;letter-spacing:-.02em;color:var(--tx-0);margin-top:2px;font-variant-numeric:tabular-nums}
        .zc-hero .n small{font-size:14px;color:var(--tx-2);font-weight:600}
        .zc-grid{display:grid;gap:10px;margin-top:12px;grid-template-columns:repeat(5,1fr)}
        .zc-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:12px 13px}
        .zc-tile .n{font-size:22px;font-weight:800;color:var(--tx-0);line-height:1;font-variant-numeric:tabular-nums}
        .zc-tile .l{font-size:11px;color:var(--tx-1);margin-top:6px;font-weight:500}
        .zc-match{background:var(--sari-z);border:1px solid rgba(138,93,6,.25);border-radius:13px;padding:13px 15px;margin-top:12px}
        .zc-match .t{font-size:14px;font-weight:800;color:var(--sari)}
        .zc-match .s{font-size:12.5px;color:var(--sari);margin-top:4px;line-height:1.5}
        .zc-sec{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.06em;margin:18px 2px 10px;display:flex;justify-content:space-between}
        .zc-card{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;overflow:hidden}
        table.zc-t{width:100%;border-collapse:collapse;font-size:13px}
        table.zc-t th{text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.04em;color:var(--tx-2);font-weight:700;padding:9px 12px;border-bottom:1px solid var(--cizgi)}
        table.zc-t td{padding:9px 12px;border-bottom:1px solid var(--cizgi);color:var(--tx-0)}
        table.zc-t tr:last-child td{border-bottom:0}
        table.zc-t td.num,table.zc-t th.num{text-align:right;font-variant-numeric:tabular-nums}
        table.zc-t tr.tik{cursor:pointer}table.zc-t tr.tik:hover td{background:var(--zemin-2)}
        .zc-go{color:var(--mavi);font-weight:700}
        .zc-daha{width:100%;border:0;background:var(--zemin-2);color:var(--tx-1);font-family:inherit;font-size:12px;font-weight:700;padding:11px;cursor:pointer}
        .zc-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}
        /* ── LEADERBOARD (yönetici) ── */
        .lb{display:flex;flex-direction:column;gap:10px}
        .lb-row{display:grid;grid-template-columns:34px 1fr 150px;gap:16px;align-items:center;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:14px 16px;transition:box-shadow .15s,transform .15s}
        .lb-row:hover{box-shadow:0 4px 16px rgba(0,0,0,.06);transform:translateY(-1px)}
        .lb-rank{font-size:15px;font-weight:800;color:var(--tx-3);text-align:center;font-variant-numeric:tabular-nums}
        .lb-row.top1 .lb-rank{color:#B8860B}.lb-row.top2 .lb-rank{color:#8a8a95}.lb-row.top3 .lb-rank{color:#a9744f}
        .lb-row.top1{border-color:rgba(184,134,11,.35);box-shadow:0 1px 0 rgba(184,134,11,.12)}
        .lb-main{min-width:0}
        .lb-name{font-size:15px;font-weight:700;color:var(--tx-0);letter-spacing:-.01em}
        .lb-sub{display:flex;gap:14px;flex-wrap:wrap;margin-top:7px;font-size:12px;color:var(--tx-1)}
        .lb-sub b{color:var(--tx-0);font-weight:700;font-variant-numeric:tabular-nums}
        .lb-bars{margin-top:10px;display:grid;grid-template-columns:1fr 1fr;gap:8px 18px}
        .lb-bar .bl{display:flex;justify-content:space-between;font-size:10.5px;color:var(--tx-2);font-weight:600;margin-bottom:3px}
        .lb-bar .bl b{color:var(--tx-1);font-variant-numeric:tabular-nums}
        .lb-track{height:6px;border-radius:999px;background:var(--zemin-2);overflow:hidden}
        .lb-fill{height:100%;border-radius:999px}
        .lb-fill.ciro{background:linear-gradient(90deg,#2563eb,#3b82f6)}
        .lb-fill.kaps{background:linear-gradient(90deg,#106B4A,#12b981)}
        .lb-fill.kaps.dus{background:linear-gradient(90deg,#C43D28,#e5734f)}
        .lb-amt{text-align:right}
        .lb-amt .v{font-size:23px;font-weight:800;color:var(--tx-0);letter-spacing:-.02em;font-variant-numeric:tabular-nums;line-height:1}
        .lb-amt .k{font-size:11px;color:var(--tx-2);margin-top:4px;font-variant-numeric:tabular-nums}
        .lb-lock{margin-top:9px;display:inline-flex;align-items:center;gap:6px;background:var(--sari-z);border:1px solid rgba(138,93,6,.22);color:var(--sari);font-size:11.5px;font-weight:700;padding:5px 9px;border-radius:999px;cursor:default}
      </style>`;
      if (d.rol === "rep") {
        const o = d.ozet || {}, ms = d.musteriler || [];
        const cirolu = ms.filter(m => m.musteri_kodu);
        const esl = ms.filter(m => !m.musteri_kodu).sort((a, b) => (b.ziyaret || 0) - (a.ziyaret || 0));
        const tbl = (arr, tik) => `<table class="zc-t"><tbody>${arr.map((m, i) => `<tr class="${tik ? "tik" : ""}" ${tik ? `data-mid="${esc(m.id)}"` : ""} ${i >= 12 ? `data-extra="1" style="display:none"` : ""}><td>${esc(m.firma)}</td><td class="num" style="color:var(--tx-2)">${m.ziyaret} ziyaret</td><td class="num">${tik ? `<span class="zc-go">eşleştir ›</span>` : kisa(m.ciro)}</td></tr>`).join("")}</tbody></table>`;
        const sec = (b, sag, arr, tik, k) => arr.length ? `<div class="zc-sec"><span>${b}</span><span style="color:var(--tx-2)">${sag}</span></div><div class="zc-card" id="zc-${k}">${tbl(arr, tik)}${arr.length > 12 ? `<button class="zc-daha" data-k="${k}">+ ${arr.length - 12} tane daha</button>` : ""}</div>` : "";
        el2.innerHTML = CSS + `<!--CIRO_UI3_DK_V1--><div class="zc">
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
        const R = (d.repler || []).slice().sort((a, b) => (Number(b.ciro) || 0) - (Number(a.ciro) || 0));
        const toplamCiro = R.reduce((s, r) => s + (Number(r.ciro) || 0), 0);
        const toplamZiy = R.reduce((s, r) => s + (Number(r.ziyaret) || 0), 0);
        const maxCiro = R.reduce((m, r) => Math.max(m, Number(r.ciro) || 0), 0) || 1;
        const kapsamlar = R.map(r => r.kapsam).filter(x => x != null).map(Number);
        const ortKapsam = kapsamlar.length ? Math.round(kapsamlar.reduce((s, x) => s + x, 0) / kapsamlar.length) : null;
        const ekipCiroZiy = toplamZiy ? toplamCiro / toplamZiy : 0;
        const acikRep = R.filter(r => (r.eslesen != null && r.benzersiz != null && r.eslesen < r.benzersiz)).length;
        const rows = R.map((r, i) => {
          const ciro = Number(r.ciro) || 0;
          const pay = Math.max(2, Math.round(ciro / maxCiro * 100));
          const kaps = r.kapsam != null ? Number(r.kapsam) : null;
          const acik = (r.eslesen != null && r.benzersiz != null) ? (r.benzersiz - r.eslesen) : 0;
          const topCls = i === 0 ? " top1" : i === 1 ? " top2" : i === 2 ? " top3" : "";
          return `<div class="lb-row${topCls}">
            <div class="lb-rank">${i + 1}</div>
            <div class="lb-main">
              <div class="lb-name">${esc(r.rep)}</div>
              <div class="lb-sub"><span>Ziyaret <b>${r.ziyaret || 0}</b></span><span>Ulaşılan <b>${r.benzersiz || 0}</b></span><span>Dönüşüm <b>${r.donusum != null ? "%" + r.donusum : "—"}</b></span><span>₺/ziyaret <b>${kisa(r.ciro_ziyaret)}</b></span></div>
              <div class="lb-bars">
                <div class="lb-bar"><div class="bl"><span>Ciro payı</span><b>${toplamCiro ? Math.round(ciro / toplamCiro * 100) : 0}%</b></div><div class="lb-track"><div class="lb-fill ciro" style="width:${pay}%"></div></div></div>
                <div class="lb-bar"><div class="bl"><span>ERP kapsamı</span><b>${kaps != null ? "%" + kaps : "—"}</b></div><div class="lb-track"><div class="lb-fill kaps${kaps != null && kaps < 60 ? " dus" : ""}" style="width:${kaps != null ? Math.max(2, kaps) : 0}%"></div></div></div>
              </div>
              ${acik > 0 ? `<div class="lb-lock">🔒 ${acik} müşteri ERP'ye bağlanınca gerçek ciro açılır</div>` : ""}
            </div>
            <div class="lb-amt"><div class="v">${kisa(ciro)}</div><div class="k">etki ciro</div></div>
          </div>`;
        }).join("");
        el2.innerHTML = CSS + `<!--CIRO_UI3_DK_V1--><div class="zc">
          <div class="zc-grid" style="grid-template-columns:repeat(4,1fr)">
            <div class="zc-hero" style="grid-column:span 1"><div class="l">Toplam etki ciro · dönem</div><div class="n">${kisa(toplamCiro)}</div></div>
            <div class="zc-tile"><div class="n">${kisa(ekipCiroZiy)}</div><div class="l">Ekip ₺ / ziyaret</div></div>
            <div class="zc-tile"><div class="n">${ortKapsam != null ? "%" + ortKapsam : "—"}</div><div class="l">Ortalama ERP kapsamı</div></div>
            <div class="zc-tile"><div class="n">${R.length}</div><div class="l">Temsilci</div></div>
          </div>
          <div class="zc-sec"><span>Ekip sıralaması · ciro etkisine göre</span><span style="color:var(--tx-2)">${R.length} temsilci</span></div>
          ${R.length ? `<div class="lb">${rows}</div>` : `<div class="zc-empty">Bu dönemde ziyaret yok.</div>`}
          ${acikRep > 0 ? `<div class="zc-match" style="margin-top:14px"><div class="t">🔒 ${acikRep} temsilcide kilitli ciro var</div><div class="s">Bazı ziyaret edilen müşteriler ERP'ye bağlı değil — o cironun tamamı burada görünmüyor. Eşleştirme tamamlandıkça sıralama ve gerçek rakamlar netleşir.</div></div>` : ""}
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
'''

s = s[:start] + NEW + s[end:]
open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_UI3_DK_V1 (masaüstü) — açık tema + leaderboard")
