# -*- coding: utf-8 -*-
# PORTFOY_MOB_V1 + KAPSAM_SAGLIK_MOB_V1 (mobil saha.js)
#   (A) Kapsam kp-meta rozeti: kayiyor/sadik → aktif/soguyor/pasif (kanonik view). CSS + render.
#   (B) "🩺 Portföy" sekmesi + rpPortfoy (kompakt kart listesi, .se DS-token deseni).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "PORTFOY_MOB_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# ── (A) rozet CSS ───────────────────────────────────────────────────────────
css_old = '.kp-tk{font-weight:700}.kp-tk.kayiyor{color:#C43D28}.kp-tk.sadik{color:#106B4A}  /* KAPSAM_RETENTION_V1 */'
css_new = '.kp-tk{font-weight:700}.kp-tk.pasif{color:#C43D28}.kp-tk.soguyor{color:#8A5D06}.kp-tk.aktif{color:#106B4A}  /* KAPSAM_SAGLIK_MOB_V1 */'
assert s.count(css_old) == 1, "rozet CSS anchor=%d" % s.count(css_old)
s = s.replace(css_old, css_new, 1)

# ── (A) rozet render ────────────────────────────────────────────────────────
r_old = '${x.tk && x.tk.durum && x.tk.durum !== "sessiz" ? ` · <b class="kp-tk ${x.tk.durum}">${x.tk.durum === "kayiyor" ? "🔴 kayıyor" : "🟢 sadık"}</b>` : ""}'
r_new = '${x.tk && x.tk.durum ? ` · <b class="kp-tk ${x.tk.durum}">${x.tk.durum === "pasif" ? "🔴 pasif" : x.tk.durum === "soguyor" ? "🟡 soğuyor" : "🟢 aktif"}</b>` : ""}'
assert s.count(r_old) == 1, "rozet render anchor=%d" % s.count(r_old)
s = s.replace(r_old, r_new, 1)

# ── (B) sekme ───────────────────────────────────────────────────────────────
tab_old = '    ["etki",        "📈 Saha ROI"],  /* ZIYARET_ETKI_MOB_V1 */'
assert s.count(tab_old) == 1, "sekme anchor=%d" % s.count(tab_old)
s = s.replace(tab_old, tab_old + '\n    ["portfoy",     "🩺 Portföy"],  /* PORTFOY_MOB_V1 */', 1)

# ── (B) router ──────────────────────────────────────────────────────────────
rt_old = '      case "etki":        rpEtki();        break;  /* ZIYARET_ETKI_MOB_V1 */'
assert s.count(rt_old) == 1, "router anchor=%d" % s.count(rt_old)
s = s.replace(rt_old, rt_old + '\n      case "portfoy":     rpPortfoy();     break;  /* PORTFOY_MOB_V1 */', 1)

# ── (B) rpPortfoy — rpKapsam'dan önce ───────────────────────────────────────
fn_anchor = '  async function rpKapsam() {  /* KAPSAM_MOB_V1 */'
assert s.count(fn_anchor) == 1, "rpKapsam anchor=%d" % s.count(fn_anchor)
FN = r'''  async function rpPortfoy() {  /* PORTFOY_MOB_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    let d; try { d = await api(`/api/saha/rapor/portfoy?_=1${tipQS()}`); } catch (e) { const b0 = icerik(); if (b0) b0.innerHTML = hata(e); return; }
    const box = icerik(); if (!box) return;
    const o = d.ozet || {}, ban = (d.bantlar || []), lst = (d.liste || []);
    const rep = d.rol === "rep";
    const kTL = (n) => { n = Math.round(Number(n) || 0); const a = Math.abs(n); if (a >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (a >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + n; };
    const durTxt = { aktif: "🟢 Aktif", soguyor: "🟡 Soğuyor", pasif: "🔴 Pasif" };
    const tipTxt = (t) => t === "TUKETICI" ? "Toptan" : t === "TICARI" ? "Filo" : (t || "");
    const recTxt = (r) => r == null ? "—" : (r <= 0 ? "bu ay" : r + " ay önce");
    const term = (t, tip) => `<span class="term" title="${esc(tip)}">${t}</span>`;
    const riskN = (Number(o.soguyor) || 0) + (Number(o.pasif) || 0);
    const maxBand = Math.max(1, ...ban.map(b => Number(b.ciro) || 0));
    const CSS = `<style>
      .pf{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--cizgi-g:rgba(0,0,0,.16);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#2a78d6;--mavi-z:#EAF2FC;--sh:0 1px 2px rgba(16,16,26,.05),0 5px 18px rgba(16,16,26,.045);color-scheme:light;padding:10px 12px 92px;color:var(--tx-0);-webkit-font-smoothing:antialiased}
      .pf *{box-sizing:border-box}
      .pf .term{border-bottom:1px dotted var(--tx-3)}
      .pf-kick{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 2px 11px}
      .pf-kick .t{font-size:10.5px;font-weight:800;letter-spacing:.07em;text-transform:uppercase;color:var(--tx-2)}
      .pf-kick .p{font-size:10px;font-weight:700;color:var(--tx-2);background:var(--zemin-2);padding:4px 10px;border-radius:999px}
      .pf-ctx{display:flex;gap:8px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;padding:11px 13px;margin-bottom:11px;font-size:11.5px;line-height:1.5;color:var(--tx-1)}
      .pf-ctx .ic{flex:0 0 auto}.pf-ctx b{color:var(--tx-0)}
      .pf-hero{background:linear-gradient(180deg,#fff,#FEFCFB);border:1px solid var(--cizgi);border-radius:18px;padding:16px 15px;box-shadow:var(--sh);margin-bottom:11px}
      .pf-hq{font-size:12px;font-weight:600;color:var(--tx-2);margin-bottom:6px}
      .pf-big{font-size:30px;font-weight:820;letter-spacing:-.02em;line-height:1;color:var(--kirmizi);font-variant-numeric:tabular-nums}
      .pf-hs{font-size:12.5px;color:var(--tx-1);margin-top:8px;line-height:1.45}.pf-hs b{color:var(--tx-0)}
      .pf-tiles{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:14px}
      .pf-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:11px 10px;position:relative;overflow:hidden}
      .pf-tile:before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px}
      .pf-tile.ak:before{background:var(--yesil)}.pf-tile.so:before{background:var(--sari)}.pf-tile.pa:before{background:var(--kirmizi)}
      .pf-tile .n{font-size:21px;font-weight:800;line-height:1;font-variant-numeric:tabular-nums}
      .pf-tile.so .n{color:var(--sari)}.pf-tile.pa .n{color:var(--kirmizi)}.pf-tile.ak .n{color:var(--yesil)}
      .pf-tile .l{font-size:11px;color:var(--tx-1);margin-top:5px;font-weight:700}
      .pf-card{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:16px;padding:14px 14px;box-shadow:var(--sh);margin-bottom:11px}
      .pf-ch{display:flex;align-items:baseline;gap:7px;margin-bottom:11px}
      .pf-ch h4{margin:0;font-size:13.5px;font-weight:800;color:var(--tx-0)}.pf-ch .sub{font-size:10px;color:var(--tx-2)}
      .pf-bd{display:flex;flex-direction:column;gap:9px}
      .pf-brow{display:block}
      .pf-blab{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:4px}
      .pf-blab .k{font-size:11.5px;font-weight:700;color:var(--tx-1)}.pf-blab .v{font-size:11px;color:var(--tx-1);font-variant-numeric:tabular-nums}
      .pf-bbar{position:relative;height:16px;background:var(--zemin-2);border-radius:6px;overflow:hidden}
      .pf-bfl{position:absolute;left:0;top:0;bottom:0;border-radius:6px;background:linear-gradient(90deg,#d68a3a,var(--sari));min-width:3px}
      .pf-lr{border:1px solid var(--cizgi);border-radius:12px;padding:10px 12px;margin-bottom:8px;background:var(--zemin-1)}
      .pf-lt{display:flex;justify-content:space-between;align-items:baseline;gap:8px}
      .pf-fm{font-weight:700;font-size:13px;color:var(--tx-0)}
      .pf-amt{font-weight:700;font-size:13px;font-variant-numeric:tabular-nums;white-space:nowrap}
      .pf-lm{font-size:11px;color:var(--tx-2);margin-top:4px;display:flex;flex-wrap:wrap;gap:4px 8px;align-items:center}
      .pf-bg{font-weight:700;font-size:10px;white-space:nowrap;padding:2px 7px;border-radius:999px}
      .pf-bg.soguyor{color:var(--sari);background:var(--sari-z)}.pf-bg.pasif{color:var(--kirmizi);background:var(--kirmizi-z)}
      .pf-dim{font-size:10px;color:var(--tx-3);font-style:italic}
      .pf-yok{display:flex;gap:11px;align-items:center;background:var(--zemin-0);border:1px dashed var(--cizgi-g);border-radius:13px;padding:12px 13px;margin-bottom:11px}
      .pf-yok .big{font-size:23px;font-weight:800;color:var(--tx-2);line-height:1;flex:0 0 auto;font-variant-numeric:tabular-nums}
      .pf-yok .tx{font-size:11.5px;line-height:1.45;color:var(--tx-1)}.pf-yok .tx b{color:var(--tx-0)}
      .pf-how{background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:14px;padding:14px;margin-bottom:11px}
      .pf-how h4{margin:0 0 8px;font-size:12.5px;font-weight:800;color:var(--tx-1)}.pf-how div{font-size:11.5px;color:var(--tx-1);line-height:1.55;margin-bottom:6px}.pf-how b{color:var(--tx-0)}
      .pf-foot{padding:12px 13px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;font-size:10.5px;line-height:1.6;color:var(--tx-2)}.pf-foot b{color:var(--tx-1)}.pf-foot .dot{color:var(--tx-3);margin:0 5px}
      .pf-empty{color:var(--tx-2);text-align:center;padding:18px;font-size:12px}
    </style>`;
    const KICK = `<div class="pf-kick"><span class="t">🩺 Portföy Sağlığı</span><span class="p">alım ritmine göre</span></div>`;
    const CTX = rep
      ? `<div class="pf-ctx"><span class="ic">🩺</span><div>Defterinde <b>${o.alimli || 0}</b> müşterinin alım geçmişi var. Her biri <b>kendi temposuna göre</b> ${term("sınıflanıyor", "aktif = kendi ritminde · soğuyor = gecikti · pasif = ritmini çok aştı / 12+ ay")}. Amaç: <b>soğuyanı pasife düşmeden yakalamak.</b></div></div>`
      : `<div class="pf-ctx"><span class="ic">🩺</span><div>Ekipte <b>${o.alimli || 0}</b> müşterinin alım geçmişi var; her biri <b>kendi temposuna göre</b> sınıflanıyor. Risk altındaki ciro aşağıda.</div></div>`;
    const HERO = `<div class="pf-hero"><div class="pf-hq">${rep ? "Defterinde risk altındaki ciro" : "Risk altındaki ciro"}</div>
      <div class="pf-big">${kTL(o.risk_ciro)}</div>
      <div class="pf-hs"><b>${riskN}</b> müşteri ritminden çıkmış — <b>${o.soguyor || 0}</b> soğuyor, <b>${o.pasif || 0}</b> pasif.</div>
      <div class="pf-tiles">
        <div class="pf-tile ak"><div class="n">${o.aktif || 0}</div><div class="l">🟢 Aktif</div></div>
        <div class="pf-tile so"><div class="n">${o.soguyor || 0}</div><div class="l">🟡 Soğuyor</div></div>
        <div class="pf-tile pa"><div class="n">${o.pasif || 0}</div><div class="l">🔴 Pasif</div></div>
      </div></div>`;
    const bandRows = ban.map((b) => {
      const w = Math.max(3, (Number(b.ciro) || 0) / maxBand * 100);
      return `<div class="pf-brow"><div class="pf-blab"><span class="k">${esc(b.etiket)}</span><span class="v">${b.n || 0} · ${kTL(b.ciro)}</span></div><div class="pf-bbar"><div class="pf-bfl" style="width:${w}%"></div></div></div>`;
    }).join("");
    const BANDS = `<div class="pf-card"><div class="pf-ch"><h4>Yaşlanma</h4><span class="sub">son alımdan bu yana</span></div><div class="pf-bd">${bandRows || `<div class="pf-empty">Veri yok</div>`}</div></div>`;
    const listCards = lst.slice(0, 60).map((x) => `<div class="pf-lr">
      <div class="pf-lt"><div class="pf-fm">${esc(x.firma)}</div><div class="pf-amt">${x.ciro > 0 ? kTL(x.ciro) : "—"}</div></div>
      <div class="pf-lm"><span class="pf-bg ${x.durum}">${durTxt[x.durum] || x.durum}</span><span>${esc(x.il || "—")}${x.tip ? " · " + tipTxt(x.tip) : ""}</span><span>· son alım ${recTxt(x.recency)}${x.ritim != null ? ` <span class="pf-dim">(ritim ~${x.ritim}a)</span>` : ""}</span>${x.guven === "dusuk" ? ` <span class="pf-dim">ritim belirsiz</span>` : ""}${!rep && x.rep ? ` · ${esc(x.rep)}` : ""}</div></div>`).join("");
    const LIST = `<div class="pf-card"><div class="pf-ch"><h4>Risk listesi</h4><span class="sub">soğuyor + pasif · ${lst.length}${d.liste_toplam > lst.length ? " / " + d.liste_toplam : ""}</span></div>${listCards || `<div class="pf-empty">Risk altında müşteri yok 🎉</div>`}</div>`;
    const YOK = (o.alim_yok) ? `<div class="pf-yok"><div class="big">${o.alim_yok}</div><div class="tx"><b>müşterinin ERP'de alım eşleşmesi yok</b> — churn değil, sinyal yok. <b>Kapsam</b>'da kör nokta olarak eşleştir.</div></div>` : "";
    const HOW = `<div class="pf-how"><h4>Durum nasıl belirleniyor?</h4>
      <div><b>Ritim</b> = son 18 ayda alım aylarının tipik boşluğu (kendi temposu).</div>
      <div>🟢 <b>Aktif</b> ritminde · 🟡 <b>Soğuyor</b> gecikti (yakalanabilir) · 🔴 <b>Pasif</b> ritmini çok aştı / 12+ ay.</div>
      <div>Sabit eşik değil. Kapsam rozeti de <b>aynı tanımı</b> kullanır.</div></div>`;
    const FOOT = `<div class="pf-foot"><b>${o.toplam || 0}</b> aktif<span class="dot">·</span><b>${o.alimli || 0}</b> alım geçmişli<span class="dot">·</span><b>${o.alim_yok || 0}</b> eşleşme yok. Betimsel — tahmin değil.</div>`;
    box.innerHTML = CSS + `<div class="pf">${KICK}${CTX}${HERO}${BANDS}${LIST}${YOK}${HOW}${FOOT}</div>`;
  }
'''
s = s.replace(fn_anchor, FN + fn_anchor, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] PORTFOY_MOB_V1 + KAPSAM_SAGLIK_MOB_V1 (mobil) — rozet rewire + Portföy sekmesi")
