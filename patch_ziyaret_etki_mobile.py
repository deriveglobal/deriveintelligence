# -*- coding: utf-8 -*-
# ZIYARET_ETKI_MOB_V1 (mobil) — "📈 Saha ROI" (yonetici) · RETENTION PIVOT (dar ekran). UPSERT.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()

# sekme — reps DE gorsun (isMgr disi, risk'ten sonra). Eski isMgr-ici yerlesimi (varsa) geri al, sonra tasi.
s = s.replace('    ...(isMgr ? [["etki", "📈 Saha ROI"], ["temsilciler", "👥 Temsilciler"]] : []),  /* ZIYARET_ETKI_MOB_V1 */',
              '    ...(isMgr ? [["temsilciler", "👥 Temsilciler"]] : []),')
if '["etki", "📈 Saha ROI"]' not in s:
    r_old = '    ["risk",        "🚨 Risk"],  /* RISK_SAHA_V1 */'
    assert s.count(r_old) == 1, "risk tab anchor=%d" % s.count(r_old)
    s = s.replace(r_old, r_old + '\n    ["etki",        "📈 Saha ROI"],  /* ZIYARET_ETKI_MOB_V1 */', 1)
if 'case "etki"' not in s:  # dispatch
    d_old = '      case "kapsam":      rpKapsam();      break;  /* KAPSAM_MOB_V1 */'
    assert s.count(d_old) == 1, "dispatch anchor=%d" % s.count(d_old)
    s = s.replace(d_old, d_old + '\n      case "etki":        rpEtki();        break;  /* ZIYARET_ETKI_MOB_V1 */', 1)

NEWFN = r'''  async function rpEtki() {  /* ZIYARET_ETKI_MOB_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    let d; try { d = await api(`/api/saha/rapor/ziyaret-etki?_=1${tipQS()}`); } catch (e) { const b0 = icerik(); if (b0) b0.innerHTML = hata(e); return; }
    const box = icerik(); if (!box) return;
    const o = d.ozet || {}, dn = d.donem || {}, kp = d.kapsam || {}, gr = (d.gruplar || []);
    const rep = d.rol === "rep";
    const AZ = 12;
    const pctR = (n) => n == null ? "—" : Math.round(n) + "%";
    const kTL = (n) => { n = Math.round(Number(n) || 0); const a = Math.abs(n); if (a >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (a >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + n; };
    const term = (t, tip) => `<span class="term" title="${esc(tip)}">${t}</span>`;
    const withT = gr.filter((g) => g.taban > 0);
    const g0 = gr[0], gHi = withT.length ? withT[withT.length - 1] : null;
    const CSS = `<style>
      .se{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--cizgi-g:rgba(0,0,0,.16);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#2a78d6;--mavi-z:#EAF2FC;--sh:0 1px 2px rgba(16,16,26,.05),0 5px 18px rgba(16,16,26,.045);color-scheme:light;padding:10px 12px 92px;color:var(--tx-0);-webkit-font-smoothing:antialiased}
      .se *{box-sizing:border-box}
      .term{border-bottom:1px dotted var(--tx-3)}
      .se-kick{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 2px 11px}
      .se-kick .t{font-size:10.5px;font-weight:800;letter-spacing:.07em;text-transform:uppercase;color:var(--tx-2)}
      .se-kick .p{font-size:10px;font-weight:700;color:var(--tx-2);background:var(--zemin-2);padding:4px 10px;border-radius:999px}
      .ctx{display:flex;gap:8px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;padding:11px 13px;margin-bottom:11px;font-size:11.5px;line-height:1.5;color:var(--tx-1)}
      .ctx .ic{flex:0 0 auto}.ctx b{color:var(--tx-0)}
      .se-hero{background:linear-gradient(180deg,#fff,#FCFEFD);border:1px solid var(--cizgi);border-radius:18px;padding:16px 15px;box-shadow:var(--sh);margin-bottom:11px}
      .hq{font-size:12px;font-weight:600;color:var(--tx-2);margin-bottom:8px}
      .verdict{font-size:16px;font-weight:750;line-height:1.42;color:var(--tx-0)}.verdict b{color:var(--yesil)}
      .rt{display:flex;flex-direction:column;gap:11px;margin-top:16px}
      .rt-row{display:block}
      .rt-lab{display:flex;align-items:baseline;justify-content:space-between;gap:8px;margin-bottom:5px}
      .rt-lab .nm{font-size:12.5px;font-weight:700;color:var(--tx-0)}.rt-lab .nm .frq{color:var(--tx-2);font-weight:600;font-size:10.5px;margin-left:4px}
      .rt-lab .n{font-size:10.5px;color:var(--tx-2);font-weight:500;white-space:nowrap}
      .rt-bar{position:relative;height:26px}
      .rt-tk{position:absolute;inset:0;background:var(--zemin-2);border-radius:8px}
      .rt-fl{position:absolute;top:0;bottom:0;left:0;border-radius:8px;background:linear-gradient(90deg,#1a936a,var(--yesil));min-width:4px}
      .rt-fl.lo{background:linear-gradient(90deg,#d68a3a,var(--sari))}
      .rt-v{position:absolute;top:50%;transform:translateY(-50%);font-size:13px;font-weight:800;font-variant-numeric:tabular-nums;white-space:nowrap}
      .ihmal{display:flex;gap:11px;align-items:center;background:var(--kirmizi-z);border:1px solid rgba(196,61,40,.2);border-radius:13px;padding:13px 14px;margin-bottom:11px}
      .ihmal .big{font-size:26px;font-weight:820;color:var(--kirmizi);line-height:1;font-variant-numeric:tabular-nums;flex:0 0 auto}
      .ihmal .tx{font-size:11.5px;line-height:1.45;color:#7a2a1a}.ihmal .tx b{color:#5c1f13}
      .baz{background:var(--mavi-z);border-radius:12px;padding:12px 13px;margin-bottom:11px;font-size:11.5px;line-height:1.5;color:#1c4f8f}.baz b{color:#123563}
      .baz .row{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}
      .baz .chip{font-size:10.5px;background:#fff;border:1px solid rgba(37,99,235,.18);border-radius:999px;padding:3px 9px;color:#1c4f8f;font-weight:600;font-variant-numeric:tabular-nums}
      .how{background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:14px;padding:14px;margin-bottom:11px}
      .how h4{margin:0 0 8px;font-size:12.5px;font-weight:800;color:var(--tx-1)}.how div{font-size:11.5px;color:var(--tx-1);line-height:1.55;margin-bottom:6px}.how b{color:var(--tx-0)}.how code{background:var(--zemin-2);padding:1px 5px;border-radius:5px;font-size:10px}
      .se-foot{padding:12px 13px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;font-size:10.5px;line-height:1.6;color:var(--tx-2)}.se-foot b{color:var(--tx-1)}.se-foot .dot{color:var(--tx-3);margin:0 5px}
      .se-empty{color:var(--tx-2);text-align:center;padding:18px;font-size:12px}
    </style>`;
    const KICK = `<div class="se-kick"><span class="t">📈 Saha ROI · sıklık → tekrar-alım</span><span class="p">son 12 ay</span></div>`;
    const CTX = rep
      ? `<div class="ctx"><span class="ic">📍</span><div>Senin defterinde <b>${kp.matched || 0}</b> aktif müşteri; son 12 ayda <b>${kp.ziyaret_edilmis || 0}'ine</b> (%${Math.round(kp.pct || 0)}) uğramışsın. <b>Ne kadar sık ziyaret ettiğin</b> ile müşterinin ${term("geri gelmesi", "H1'de alan müşterinin H2'de de alması. Tutara duyarsız.")} ilişkisi. Az müşterili grupta sayı oynak.</div></div>`
      : `<div class="ctx"><span class="ic">📍</span><div>Ekip <b>${kp.matched || 0}</b> aktif müşterinin <b>${kp.ziyaret_edilmis || 0}'ine</b> (%${Math.round(kp.pct || 0)}) uğramış — kapsam neredeyse tam. "Ziyaret edilen vs edilmeyen" kıyası kurulamaz; onun yerine <b>ziyaret sıklığının</b> ${term("tekrar-alımla", "H1'de (önceki 6 ay) alan müşterinin H2'de (son 6 ay) de alması. Tutara duyarsız.")} ilişkisi.</div></div>`;
    const verdict = (g0 && gHi && g0.retention != null && gHi.retention != null)
      ? `Daha sık ziyaret edilen daha çok geri geliyor: yılda <b>hiç uğranmayanın %${Math.round(g0.retention)}'ı</b> tekrar alırken, <b>${esc(gHi.aralik)} ziyaret edilenin %${Math.round(gHi.retention)}'ı</b> alıyor.`
      : `Ziyaret sıklığı ile tekrar-alım (aşağıda).`;
    const rtRows = gr.map((g) => {
      const az = (g.taban || 0) < AZ;
      const w = g.retention == null ? 0 : Math.max(4, g.retention);
      const inside = (g.retention || 0) > 22;
      const vst = inside ? `right:calc(${100 - w}% + 8px);color:#fff` : `left:calc(${w}% + 8px);color:var(--tx-0)`;
      const lo = (g.retention != null && g.retention < 65);
      return `<div class="rt-row"><div class="rt-lab"><div class="nm">${esc(g.etiket)}<span class="frq">${esc(g.aralik)} ziy/yıl</span></div><div class="n">${g.taban || 0} müşteri${az ? " · az" : ""}</div></div>
        <div class="rt-bar"><div class="rt-tk"></div><div class="rt-fl ${lo ? "lo" : ""}" style="width:${w}%"></div><span class="rt-v" style="${vst}">${pctR(g.retention)}</span></div></div>`;
    }).join("");
    const HERO = `<div class="se-hero"><div class="hq">Daha çok ziyaret, müşteriyi elde tutuyor mu?</div>
      <div class="verdict">${verdict}</div><div class="rt">${rtRows || `<div class="se-empty">Veri yok</div>`}</div></div>`;
    const IHMAL = (o.ihmal_n) ? `<div class="ihmal"><div class="big">${o.ihmal_n}</div><div class="tx"><b>${rep ? "müşterine son 12 ayda hiç uğramamışsın." : "müşteri son 12 ayda hiç ziyaret edilmemiş."}</b> Ort. yıllık ciro <b>${kTL(o.ihmal_ort_ciro)}</b>, tekrar-alım yalnız <b>%${Math.round(o.ihmal_retention || 0)}</b> — en riskli cep.</div></div>` : "";
    const bazChips = withT.map((g) => `<span class="chip">${esc(g.aralik)}: ${kTL(g.ort_ciro)}</span>`).join("");
    const BAZ = `<div class="baz"><b>⚖️ Kıyas adil mi?</b> Bu <b>korelasyon</b>, nedensellik değil — sık ziyaret edilenler zaten daha büyük/bağlı olabilir. Grup öncesi ort. ciro:<div class="row">${bazChips}</div></div>`;
    const HOW = `<div class="how"><h4>Nasıl hesaplanıyor?</h4>
      <div><b>Ziyaret sıklığı</b> = son 12 ayda tamamlanmış ziyaret; 0 / 1-3 / 4-8 / 9+ grupları.</div>
      <div><b>Tekrar-alım</b> = önceki 6 ayda (H1) alan müşterinin son 6 ayda (H2) da alma oranı. Ciro <b>tutarına duyarsız</b> → birkaç dev müşteri/düzensiz alım bozmaz.</div>
      <div>Eşleşme <code>musteri_kodu</code>; yalnız H1'de alanlar paydada. Ciro büyümesi çok dağınık olduğundan manşet yapılmadı.</div></div>`;
    const FOOT = `<div class="se-foot"><b>Genel tekrar-alım %${Math.round(o.genel_retention || 0)}</b> (${o.taban_toplam || 0} müşteri)<span class="dot">·</span>Sıklık ${dn.yil ? dn.yil.join("→") : "—"}<span class="dot">·</span>H1 ${dn.h1 ? dn.h1.join("→") : "—"}<span class="dot">·</span>H2 ${dn.h2 ? dn.h2.join("→") : "—"}. Veri sonu ${dn.veri_sonu || "—"}.</div>`;
    box.innerHTML = CSS + `<div class="se">${KICK}${CTX}${HERO}${IHMAL}${BAZ}${HOW}${FOOT}</div>`;
  }
'''

KAP = "  async function rpKapsam() {  /* KAPSAM_MOB_V1 */"
if "  async function rpEtki()" in s:
    a = s.index("  async function rpEtki()")
    b = s.index(KAP, a)
    s = s[:a] + NEWFN + s[b:]
else:
    assert s.count(KAP) == 1, "rpKapsam anchor=%d" % s.count(KAP)
    s = s.replace(KAP, NEWFN + KAP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_ETKI_MOB_V1 (mobil · retention · upsert)")
