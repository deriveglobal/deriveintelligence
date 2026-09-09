# -*- coding: utf-8 -*-
# PORTFOY_DK_V1 + KAPSAM_SAGLIK_DK_V1 (masaüstü saha_desktop.js)
#   (A) Kapsam rozeti: kayiyor/sadik → aktif/soguyor/pasif (kanonik view durumu). CSS + render.
#   (B) "🩺 Portföy" sekmesi + rpPortfoy (aynı .se DS-token deseni, scoped .pf wrapper).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "PORTFOY_DK_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# ── (A) rozet CSS ───────────────────────────────────────────────────────────
css_old = '.kap-tk.kayiyor{color:#C43D28}.kap-tk.sadik{color:#106B4A}/* KAPSAM_RETENTION_V1 */'
css_new = '.kap-tk.pasif{color:#C43D28}.kap-tk.soguyor{color:#8A5D06}.kap-tk.aktif{color:#106B4A}/* KAPSAM_SAGLIK_DK_V1 */'
assert s.count(css_old) == 1, "rozet CSS anchor=%d" % s.count(css_old)
s = s.replace(css_old, css_new, 1)

# ── (A) rozet render ────────────────────────────────────────────────────────
r_old = '${x.tk && x.tk.durum && x.tk.durum !== "sessiz" ? ` · <span class="kap-tk ${x.tk.durum}" title="son 12 ay ${x.tk.vc} ziyaret">${x.tk.durum === "kayiyor" ? "🔴 kayıyor" : "🟢 sadık"}</span>` : ""}'
r_new = '${x.tk && x.tk.durum ? ` · <span class="kap-tk ${x.tk.durum}" title="son 12 ay ${x.tk.vc} ziyaret · alım ritmine göre">${x.tk.durum === "pasif" ? "🔴 pasif" : x.tk.durum === "soguyor" ? "🟡 soğuyor" : "🟢 aktif"}</span>` : ""}'
assert s.count(r_old) == 1, "rozet render anchor=%d" % s.count(r_old)
s = s.replace(r_old, r_new, 1)

# ── (B) sekme ───────────────────────────────────────────────────────────────
tab_old = '    ["etki", "📈 Saha ROI"],  /* ZIYARET_ETKI_DK_V1 */'
tab_new = tab_old + '\n    ["portfoy", "🩺 Portföy"],  /* PORTFOY_DK_V1 */'
assert s.count(tab_old) == 1, "sekme anchor=%d" % s.count(tab_old)
s = s.replace(tab_old, tab_new, 1)

# ── (B) RENDER map ──────────────────────────────────────────────────────────
map_old = 'const RENDER = { ozet: rpOzet, ciro: rpCiro, risk: rpRisk, rotam: rpRotam, etki: rpEtki, kapsam: rpKapsam, temsilciler: rpTemsilciler, pipeline: rpPipeline, pazar: rpPazar };  /* KAPSAM_DK_V1 */'
map_new = 'const RENDER = { ozet: rpOzet, ciro: rpCiro, risk: rpRisk, rotam: rpRotam, etki: rpEtki, portfoy: rpPortfoy, kapsam: rpKapsam, temsilciler: rpTemsilciler, pipeline: rpPipeline, pazar: rpPazar };  /* PORTFOY_DK_V1 */'
assert s.count(map_old) == 1, "RENDER map anchor=%d" % s.count(map_old)
s = s.replace(map_old, map_new, 1)

# ── (B) rpPortfoy fonksiyonu — rpKapsam'dan önce ────────────────────────────
fn_anchor = '  async function rpKapsam() {  /* KAPSAM_DK_V1 */'
assert s.count(fn_anchor) == 1, "rpKapsam anchor=%d" % s.count(fn_anchor)
FN = r'''  async function rpPortfoy() {  /* PORTFOY_DK_V1 */
    const el = icerik(); if (!el) return; el.innerHTML = load();
    let d; try { d = await api(`/api/saha/rapor/portfoy?_=1${tipQS()}`); } catch (e) { const b0 = icerik(); if (b0) b0.innerHTML = hataH(e); return; }
    const box = icerik(); if (!box) return;
    const o = d.ozet || {}, ban = (d.bantlar || []), lst = (d.liste || []), tem = (d.temsilci || []);
    const rep = d.rol === "rep";
    const kTL = (n) => { n = Math.round(Number(n) || 0); const a = Math.abs(n); if (a >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (a >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + n; };
    const durTxt = { aktif: "🟢 Aktif", soguyor: "🟡 Soğuyor", pasif: "🔴 Pasif" };
    const recTxt = (r) => r == null ? "—" : (r <= 0 ? "bu ay" : r + " ay önce");
    const term = (t, tip) => `<span class="term" title="${esc(tip)}">${t}</span>`;
    const riskN = (Number(o.soguyor) || 0) + (Number(o.pasif) || 0);
    const maxBand = Math.max(1, ...ban.map(b => Number(b.ciro) || 0));
    const CSS = `<style>
      .pf{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--cizgi-g:rgba(0,0,0,.16);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#2a78d6;--mavi-z:#EAF2FC;--sh:0 1px 2px rgba(16,16,26,.05),0 6px 22px rgba(16,16,26,.045);color-scheme:light;color:var(--tx-0);font-family:var(--sans,system-ui,-apple-system,'Segoe UI',sans-serif);-webkit-font-smoothing:antialiased}
      .pf *{box-sizing:border-box}
      .pf .term{border-bottom:1px dotted var(--tx-3);cursor:help}
      .pf-kick{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:2px 2px 12px}
      .pf-kick .t{font-size:11px;font-weight:800;letter-spacing:.10em;text-transform:uppercase;color:var(--tx-2)}
      .pf-kick .p{font-size:11px;font-weight:700;color:var(--tx-2);background:var(--zemin-2);padding:5px 12px;border-radius:999px}
      .pf-ctx{display:flex;gap:10px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;padding:12px 15px;margin-bottom:13px;font-size:12px;line-height:1.55;color:var(--tx-1)}
      .pf-ctx .ic{flex:0 0 auto;font-size:15px}.pf-ctx b{color:var(--tx-0)}
      .pf-hero{background:linear-gradient(180deg,#fff,#FEFCFB);border:1px solid var(--cizgi);border-radius:20px;padding:22px 24px;box-shadow:var(--sh);margin-bottom:13px}
      .pf-hq{font-size:12.5px;font-weight:600;color:var(--tx-2);margin-bottom:7px}
      .pf-big{font-size:34px;font-weight:820;letter-spacing:-.02em;line-height:1;color:var(--kirmizi);font-variant-numeric:tabular-nums}
      .pf-hs{font-size:13.5px;color:var(--tx-1);margin-top:9px;line-height:1.5}.pf-hs b{color:var(--tx-0)}
      .pf-tiles{display:grid;grid-template-columns:repeat(3,1fr);gap:11px;margin:16px 0 13px}
      .pf-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:14px 15px;position:relative;overflow:hidden}
      .pf-tile:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px}
      .pf-tile.ak:before{background:var(--yesil)}.pf-tile.so:before{background:var(--sari)}.pf-tile.pa:before{background:var(--kirmizi)}
      .pf-tile .n{font-size:25px;font-weight:800;letter-spacing:-.02em;line-height:1;font-variant-numeric:tabular-nums}
      .pf-tile.so .n{color:var(--sari)}.pf-tile.pa .n{color:var(--kirmizi)}.pf-tile.ak .n{color:var(--yesil)}
      .pf-tile .l{font-size:12px;color:var(--tx-1);margin-top:6px;font-weight:700}
      .pf-tile .sx{font-size:10.5px;color:var(--tx-2);margin-top:2px;font-variant-numeric:tabular-nums}
      .pf-card{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:16px;padding:18px 20px;box-shadow:var(--sh);margin-bottom:13px}
      .pf-ch{display:flex;align-items:baseline;gap:9px;margin-bottom:12px}
      .pf-ch .tick{width:4px;height:15px;border-radius:2px;background:var(--tx-3);transform:translateY(2px)}
      .pf-ch h4{margin:0;font-size:15px;font-weight:800;color:var(--tx-0)}.pf-ch .sub{font-size:11px;color:var(--tx-2)}
      .pf-bd{display:flex;flex-direction:column;gap:10px}
      .pf-brow{display:grid;grid-template-columns:96px 1fr auto;gap:12px;align-items:center}
      .pf-blab{font-size:12.5px;font-weight:700;color:var(--tx-1);font-variant-numeric:tabular-nums}
      .pf-bbar{position:relative;height:22px;background:var(--zemin-2);border-radius:7px;overflow:hidden}
      .pf-bfl{position:absolute;left:0;top:0;bottom:0;border-radius:7px;background:linear-gradient(90deg,#d68a3a,var(--sari));min-width:3px}
      .pf-bv{font-size:12.5px;font-weight:700;color:var(--tx-0);font-variant-numeric:tabular-nums;white-space:nowrap;min-width:120px;text-align:right}
      .pf table{width:100%;border-collapse:collapse;background:var(--zemin-1)}
      .pf th{font-size:9.5px;text-transform:uppercase;letter-spacing:.04em;color:var(--tx-2);font-weight:700;text-align:left;padding:0 8px 9px}
      .pf th.r,.pf td.r{text-align:right}
      .pf td{padding:9px 8px;border-top:1px solid var(--cizgi);font-size:12.5px;vertical-align:middle}
      .pf-fm{font-weight:600;color:var(--tx-0)}.pf-sub{font-size:10px;color:var(--tx-2);margin-top:2px}
      .pf-bg{font-weight:700;font-size:10px;white-space:nowrap;padding:2px 8px;border-radius:999px}
      .pf-bg.soguyor{color:var(--sari);background:var(--sari-z)}.pf-bg.pasif{color:var(--kirmizi);background:var(--kirmizi-z)}
      .pf-money{font-variant-numeric:tabular-nums;font-weight:700}.pf-mut{color:var(--tx-2)}
      .pf-dim{font-size:10px;color:var(--tx-3);font-style:italic}
      .pf-yok{display:flex;gap:12px;align-items:center;background:var(--zemin-0);border:1px dashed var(--cizgi-g);border-radius:14px;padding:14px 16px;margin-bottom:13px}
      .pf-yok .big{font-size:26px;font-weight:800;color:var(--tx-2);line-height:1;flex:0 0 auto;font-variant-numeric:tabular-nums}
      .pf-yok .tx{font-size:12px;line-height:1.5;color:var(--tx-1)}.pf-yok .tx b{color:var(--tx-0)}
      .pf-how{background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:14px;padding:16px 18px;margin-bottom:13px}
      .pf-how h4{margin:0 0 9px;font-size:13px;font-weight:800;color:var(--tx-1)}
      .pf-how div{font-size:12px;color:var(--tx-1);line-height:1.6;margin-bottom:6px}.pf-how b{color:var(--tx-0)}
      .pf-how .lg{display:inline-flex;gap:5px;align-items:center;margin-right:12px}
      .pf-foot{padding:13px 15px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;font-size:11px;line-height:1.65;color:var(--tx-2)}.pf-foot b{color:var(--tx-1)}.pf-foot .dot{color:var(--tx-3);margin:0 6px}
      .pf-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}
    </style>`;
    const KICK = `<div class="pf-kick"><span class="t">🩺 Portföy Sağlığı · alım ritmine göre</span><span class="p">son 18 ay</span></div>`;
    const CTX = rep
      ? `<div class="pf-ctx"><span class="ic">🩺</span><div>Kendi defterinde <b>${o.alimli || 0}</b> müşterinin alım geçmişi var. Aşağıda her birinin <b>kendi alım temposuna göre</b> ${term("sağlık durumu", "aktif = kendi ritminde alıyor · soğuyor = ritmine göre gecikti · pasif = ritmini çok aştı ya da 12+ ay sessiz")}. Amaç: <b>soğuyanı pasife düşmeden yakalamak.</b></div></div>`
      : `<div class="pf-ctx"><span class="ic">🩺</span><div>Ekipte <b>${o.alimli || 0}</b> müşterinin alım geçmişi var. Her müşteri <b>kendi alım temposuna göre</b> ${term("sınıflanıyor", "aktif = kendi ritminde · soğuyor = gecikti · pasif = ritmini çok aştı / 12+ ay sessiz")} — sabit bir eşik değil. Aşağıda risk altındaki ciro ve hangi temsilcinin defteri kayıyor.</div></div>`;
    const HERO = `<div class="pf-hero"><div class="pf-hq">${rep ? "Defterinde risk altındaki ciro" : "Risk altındaki ciro (soğuyor + pasif)"}</div>
      <div class="pf-big">${kTL(o.risk_ciro)}</div>
      <div class="pf-hs"><b>${riskN}</b> müşteri ritminden çıkmış — <b>${o.soguyor || 0}</b> soğuyor, <b>${o.pasif || 0}</b> pasif. ${rep ? "Soğuyanı önce ara; pasif olan çoktan kaymış." : ""}</div>
      <div class="pf-tiles">
        <div class="pf-tile ak"><div class="n">${o.aktif || 0}</div><div class="l">🟢 Aktif</div><div class="sx">${kTL(o.aktif_ciro)} ciro</div></div>
        <div class="pf-tile so"><div class="n">${o.soguyor || 0}</div><div class="l">🟡 Soğuyor</div><div class="sx">ritmine göre gecikti</div></div>
        <div class="pf-tile pa"><div class="n">${o.pasif || 0}</div><div class="l">🔴 Pasif</div><div class="sx">ritmini çok aştı / 12+ ay</div></div>
      </div></div>`;
    const bandRows = ban.map((b) => {
      const w = Math.max(3, (Number(b.ciro) || 0) / maxBand * 100);
      return `<div class="pf-brow"><div class="pf-blab">${esc(b.etiket)}</div><div class="pf-bbar"><div class="pf-bfl" style="width:${w}%"></div></div><div class="pf-bv">${b.n || 0} müşteri · ${kTL(b.ciro)}</div></div>`;
    }).join("");
    const BANDS = `<div class="pf-card"><div class="pf-ch"><span class="tick"></span><h4>Yaşlanma — son alımdan bu yana</h4><span class="sub">alım geçmişi olan müşteriler</span></div><div class="pf-bd">${bandRows || `<div class="pf-empty">Veri yok</div>`}</div></div>`;
    const yon = !rep;
    const listRows = lst.map((x) => `<tr>
      <td><div class="pf-fm">${esc(x.firma)}</div><div class="pf-sub">${esc(x.il || "—")}${x.tip ? " · " + (x.tip === "TUKETICI" ? "Toptan" : x.tip === "TICARI" ? "Filo" : esc(x.tip)) : ""}${x.segment ? " · " + esc(x.segment) : ""}</div></td>
      <td><span class="pf-bg ${x.durum}">${durTxt[x.durum] || x.durum}</span>${x.guven === "dusuk" ? ` <span class="pf-dim" title="3'ten az alım ayı — tempo belirsiz, sade recency">ritim belirsiz</span>` : ""}</td>
      <td class="pf-mut">${recTxt(x.recency)}${x.ritim != null ? ` <span class="pf-dim">(ritim ~${x.ritim} ay)</span>` : ""}</td>
      <td class="r pf-money">${x.ciro > 0 ? kTL(x.ciro) : "<span class='pf-mut'>—</span>"}</td>
      ${yon ? `<td class="pf-mut">${esc(x.rep || "—")}</td>` : ""}</tr>`).join("");
    const LIST = `<div class="pf-card"><div class="pf-ch"><span class="tick" style="background:var(--kirmizi)"></span><h4>Risk listesi — soğuyor + pasif</h4><span class="sub">risk altındaki ciroya göre · ${lst.length}${d.liste_toplam > lst.length ? " / " + d.liste_toplam : ""}</span></div>
      <table><thead><tr><th>Müşteri</th><th>Durum</th><th>Son alım</th><th class="r">12a ciro</th>${yon ? "<th>Sorumlu</th>" : ""}</tr></thead><tbody>${listRows || `<tr><td colspan="${yon ? 5 : 4}" class="pf-empty">Risk altında müşteri yok 🎉</td></tr>`}</tbody></table></div>`;
    const REP = (yon && tem.length) ? `<div class="pf-card"><div class="pf-ch"><span class="tick"></span><h4>Temsilci bazında risk</h4><span class="sub">defterinde ne kadar ciro kayıyor</span></div>
      <table><thead><tr><th>Temsilci</th><th class="r">Soğuyor</th><th class="r">Pasif</th><th class="r">Risk ₺</th></tr></thead><tbody>${tem.map(t => `<tr><td class="pf-fm">${esc(t.rep)}</td><td class="r">${t.soguyor || 0}</td><td class="r">${t.pasif || 0}</td><td class="r pf-money">${kTL(t.risk_ciro)}</td></tr>`).join("")}</tbody></table></div>` : "";
    const YOK = (o.alim_yok) ? `<div class="pf-yok"><div class="big">${o.alim_yok}</div><div class="tx"><b>müşterinin ERP'de alım eşleşmesi yok</b> (kodsuz ya da hiç almamış). Bunlar <b>churn değil</b> — sinyal yok. Kör nokta olarak <b>Kapsam</b> raporunda eşleştir/ata.</div></div>` : "";
    const HOW = `<div class="pf-how"><h4>Durum nasıl belirleniyor?</h4>
      <div><b>Ritim</b> = müşterinin son 18 ayda alım yaptığı aylar arası tipik boşluk (kendi temposu).</div>
      <div><span class="lg">🟢 <b>Aktif</b></span> kendi ritminde alıyor · <span class="lg">🟡 <b>Soğuyor</b></span> ritmine göre gecikti (yakalanabilir) · <span class="lg">🔴 <b>Pasif</b></span> ritmini çok aştı ya da 12+ ay sessiz.</div>
      <div>Sabit bir "6 ay" eşiği değil — aylık alan için 3 ay geç kalmak farklı, 6 ayda bir alan için farklıdır. Kapsam listesindeki rozet de <b>aynı tanımı</b> kullanır (tek kaynak).</div></div>`;
    const FOOT = `<div class="pf-foot"><b>${o.toplam || 0}</b> aktif müşteri<span class="dot">·</span><b>${o.alimli || 0}</b> alım geçmişli (sınıflanan)<span class="dot">·</span><b>${o.alim_yok || 0}</b> ERP eşleşmesi yok. Alım = <code>bi_satis_faturalari</code> (musteri_kodu). Korelasyon/betimsel — tahmin değil.</div>`;
    box.innerHTML = CSS + `<div class="pf">${KICK}${CTX}${HERO}${BANDS}${LIST}${REP}${YOK}${HOW}${FOOT}</div>`;
  }
'''
s = s.replace(fn_anchor, FN + fn_anchor, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] PORTFOY_DK_V1 + KAPSAM_SAGLIK_DK_V1 (masaüstü) — rozet rewire + Portföy sekmesi")
