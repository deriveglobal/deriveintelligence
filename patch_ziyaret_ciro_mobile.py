# -*- coding: utf-8 -*-
# ZIYARET_CIRO_UI_V1 (mobil) — Rapor'a "💰 Ciro" sekmesi (rep: ziyaret→ciro + eşleşmemiş nudge; yönetici: ekip matrisi).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "ZIYARET_CIRO_UI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) sekme
t_old = '    ["ozet",        "📊 Özet"],'
t_new = '    ["ozet",        "📊 Özet"],\n    ["ciro",        "💰 Ciro"],  /* ZIYARET_CIRO_UI_V1 */'
assert s.count(t_old) == 1, "tab anchor=%d" % s.count(t_old)
s = s.replace(t_old, t_new, 1)

# 2) dispatch
d_old = '      case "ozet":        rpOzet();        break;'
d_new = '      case "ozet":        rpOzet();        break;\n      case "ciro":        rpCiro();        break;'
assert s.count(d_old) == 1, "dispatch anchor=%d" % s.count(d_old)
s = s.replace(d_old, d_new, 1)

# 3) rpCiro fonksiyonu — rpTemsilciler'den önce
r_anchor = "  async function rpTemsilciler() {"
RP = r'''  async function rpCiro() {  /* ZIYARET_CIRO_UI_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const d = await api(`/api/saha/rapor/ziyaret-ciro?from=${rpFrom()}&to=${rpTo()}${tipQS()}`);
      const el2 = icerik(); if (!el2) return;
      const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
      const CSS = `<style>
        .zc{padding:10px 12px}
        .zc-hero{background:#fff;border:1px solid #e8edf3;border-radius:14px;padding:15px;box-shadow:0 1px 3px rgba(15,23,42,.06)}
        .zc-hero .l{font-size:12px;font-weight:600;color:#475569}.zc-hero .n{font-size:32px;font-weight:800;letter-spacing:-.02em;color:#0f172a;margin-top:2px}.zc-hero .n small{font-size:13px;color:#94a3b8;font-weight:600}
        .zc-grid{display:grid;gap:8px;grid-template-columns:repeat(3,1fr);margin-top:10px}
        .zc-tile{background:#fff;border:1px solid #e8edf3;border-radius:12px;padding:10px 11px}
        .zc-tile .n{font-size:19px;font-weight:800;color:#0f172a;line-height:1}.zc-tile .l{font-size:10.5px;color:#475569;margin-top:5px;font-weight:500}
        .zc-match{background:linear-gradient(135deg,#fff7ed,#fef2f2);border:1px solid #fed7aa;border-radius:12px;padding:12px;margin-top:10px}
        .zc-match .t{font-size:13px;font-weight:800;color:#9a3412}.zc-match .s{font-size:12px;color:#9a3412;margin-top:4px;line-height:1.5}
        .zc-sec{font-size:11px;font-weight:800;color:#475569;text-transform:uppercase;letter-spacing:.05em;margin:16px 2px 8px}
        .zc-card{background:#fff;border:1px solid #e8edf3;border-radius:12px;overflow:hidden}
        table.zc-t{width:100%;border-collapse:collapse;font-size:12.5px}
        table.zc-t th{text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.04em;color:#94a3b8;font-weight:700;padding:7px 10px;border-bottom:1px solid #e8edf3}
        table.zc-t td{padding:8px 10px;border-bottom:1px solid #f1f5f9}
        table.zc-t td.num,table.zc-t th.num{text-align:right}
        .zc-x{font-size:9px;font-weight:800;color:#dc2626;background:#fef2f2;padding:1px 6px;border-radius:999px;white-space:nowrap}
      </style>`;
      if (d.rol === "rep") {
        const o = d.ozet || {}, ms = d.musteriler || [];
        el2.innerHTML = CSS + `<!--ZIYARET_CIRO_UI_V1--><div class="zc">
          <div class="zc-hero" title="Ziyaret ettiğin müşterilerin dönemdeki ERP cirosu ÷ ziyaret sayın.">
            <div class="l">Ziyaret başına ciro · dönem</div><div class="n">${kisa(o.ciro_ziyaret)}<small>/ziyaret</small></div>
          </div>
          <div class="zc-grid">
            <div class="zc-tile"><div class="n">${o.ziyaret || 0}</div><div class="l">Ziyaret</div></div>
            <div class="zc-tile"><div class="n">${o.benzersiz || 0}</div><div class="l">Ulaşılan müşteri</div></div>
            <div class="zc-tile" title="ERP'de alışverişi görünen eşleşmiş müşteri oranı (kazanma değil)."><div class="n">${o.donusum != null ? "%" + o.donusum : "—"}</div><div class="l">Dönüşüm</div></div>
          </div>
          <div class="zc-grid" style="grid-template-columns:repeat(2,1fr)">
            <div class="zc-tile"><div class="n">${kisa(o.ciro)}</div><div class="l">Toplam ERP ciro</div></div>
            <div class="zc-tile"><div class="n">${o.eslesen || 0}<span style="font-size:12px;color:#94a3b8"> / ${o.benzersiz || 0}</span></div><div class="l">ERP'ye bağlı müşteri</div></div>
          </div>
          ${o.eslesmemis > 0 ? `<div class="zc-match"><div class="t">🔒 ${o.eslesmemis} müşterin ERP'ye bağlı değil</div><div class="s">Bu ziyaretlerin cirosu görünmüyor. Müşteri kartından <b>ERP eşleştir</b> → gerçek ziyaret-başına-cironu gör.</div></div>` : ""}
          <div class="zc-sec">Ziyaret ettiğin müşteriler</div>
          <div class="zc-card"><table class="zc-t"><thead><tr><th>Müşteri</th><th class="num">Ziyaret</th><th class="num">ERP Ciro</th></tr></thead><tbody>
            ${ms.length ? ms.map(m => `<tr><td>${esc(m.firma)}${!m.musteri_kodu ? ` <span class="zc-x">eşleşmemiş</span>` : ""}</td><td class="num">${m.ziyaret}</td><td class="num">${m.musteri_kodu ? kisa(m.ciro) : "—"}</td></tr>`).join("") : `<tr><td colspan="3" style="color:#94a3b8;text-align:center;padding:14px">Bu dönemde ziyaret yok.</td></tr>`}
          </tbody></table></div>
        </div>`;
      } else {
        const R = d.repler || [];
        el2.innerHTML = CSS + `<!--ZIYARET_CIRO_UI_V1--><div class="zc">
          <div class="zc-sec">Ekip · Ziyaret → Ciro</div>
          <div class="zc-card"><table class="zc-t"><thead><tr><th>Temsilci</th><th class="num">Ziyaret</th><th class="num">Kapsam</th><th class="num">₺/ziy.</th><th class="num">Etki ciro</th></tr></thead><tbody>
            ${R.length ? R.map(r => `<tr><td>${esc(r.rep)}${r.eslesen < r.benzersiz ? ` <span class="zc-x" title="${r.benzersiz - r.eslesen} müşteri eşleşmemiş">${r.eslesen}/${r.benzersiz}</span>` : ""}</td><td class="num">${r.ziyaret}</td><td class="num">${r.kapsam != null ? "%" + r.kapsam : "—"}</td><td class="num">${kisa(r.ciro_ziyaret)}</td><td class="num">${kisa(r.ciro)}</td></tr>`).join("") : `<tr><td colspan="5" style="color:#94a3b8;text-align:center;padding:14px">Bu dönemde ziyaret yok.</td></tr>`}
          </tbody></table></div>
          <div class="zc-match" style="margin-top:12px"><div class="t">Eşleşme kapsamı etkiyi gizliyor olabilir</div><div class="s">"X/Y" işaretli temsilcilerde bazı müşteriler ERP'ye bağlı değil — etki ciroları düşük görünür. Eşleştirme arttıkça gerçek rakam yükselir.</div></div>
        </div>`;
      }
    } catch (e) { const el2 = icerik(); if (el2) el2.innerHTML = hata(e); }
  }
  async function rpTemsilciler() {'''
assert s.count(r_anchor) == 1, "rpCiro anchor=%d" % s.count(r_anchor)
s = s.replace(r_anchor, RP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_CIRO_UI_V1 (mobil)")
