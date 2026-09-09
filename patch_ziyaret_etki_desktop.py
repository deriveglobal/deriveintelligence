# -*- coding: utf-8 -*-
# ZIYARET_ETKI_DK_V1 (masaustu) — "📈 Saha ROI" (yonetici) · RETENTION PIVOT.
#   KRB kapsam ~%98 -> kontrol yok. Manset: ZIYARET SIKLIGI -> TEKRAR-ALIM (robust). Merdiven gorseli.
#   Ihmal cebi (hic ziyaretsiz degerli musteri) + baz sfaflik (secim) + durust cerceve. UPSERT.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()

# sekme — reps DE gorsun (isMgr disi, risk'ten sonra). Eski isMgr-ici yerlesimi (varsa) geri al, sonra tasi.
s = s.replace('...(isMgr ? [["etki", "📈 Saha ROI"], ["kapsam", "📍 Kapsam"], ["temsilciler", "👥 Temsilciler"]] : []),  /* KAPSAM_DK_V1 ZIYARET_ETKI_DK_V1 */',
              '...(isMgr ? [["kapsam", "📍 Kapsam"], ["temsilciler", "👥 Temsilciler"]] : []),  /* KAPSAM_DK_V1 */')
if '["etki", "📈 Saha ROI"]' not in s:
    r_old = '    ["risk", "🚨 Risk"],  /* RISK_SAHA_DK_V1 */'
    assert s.count(r_old) == 1, "risk tab anchor=%d" % s.count(r_old)
    s = s.replace(r_old, r_old + '\n    ["etki", "📈 Saha ROI"],  /* ZIYARET_ETKI_DK_V1 */', 1)
if "etki: rpEtki," not in s:  # RENDER
    assert s.count("kapsam: rpKapsam,") == 1, "render anchor"
    s = s.replace("kapsam: rpKapsam,", "etki: rpEtki, kapsam: rpKapsam,", 1)
if 'aktif === "etki"' not in s:  # tarih-bari gizle
    k_old = '(aktif === "risk" || aktif === "rotam" || aktif === "kapsam")'
    assert s.count(k_old) == 1, "kontrol anchor"
    s = s.replace(k_old, '(aktif === "risk" || aktif === "rotam" || aktif === "kapsam" || aktif === "etki")', 1)

NEWFN = r'''  async function rpEtki() {  /* ZIYARET_ETKI_DK_V1 */
    const el = icerik(); if (!el) return; el.innerHTML = load();
    let d; try { d = await api(`/api/saha/rapor/ziyaret-etki?_=1${tipQS()}`); } catch (e) { const b0 = icerik(); if (b0) b0.innerHTML = hataH(e); return; }
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
      .se{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--cizgi-g:rgba(0,0,0,.16);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#2a78d6;--mavi-z:#EAF2FC;--sh:0 1px 2px rgba(16,16,26,.05),0 6px 22px rgba(16,16,26,.045);color-scheme:light;color:var(--tx-0);font-family:var(--sans,system-ui,-apple-system,'Segoe UI',sans-serif);-webkit-font-smoothing:antialiased}
      .se *{box-sizing:border-box}
      .term{border-bottom:1px dotted var(--tx-3);cursor:help}
      .tech{font-size:10.5px;font-weight:600;color:var(--tx-3);font-style:italic;margin-left:7px}
      .se-kick{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:2px 2px 12px}
      .se-kick .t{font-size:11px;font-weight:800;letter-spacing:.10em;text-transform:uppercase;color:var(--tx-2)}
      .se-kick .p{font-size:11px;font-weight:700;color:var(--tx-2);background:var(--zemin-2);padding:5px 12px;border-radius:999px}
      .ctx{display:flex;gap:10px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;padding:12px 15px;margin-bottom:13px;font-size:12px;line-height:1.55;color:var(--tx-1)}
      .ctx .ic{flex:0 0 auto;font-size:15px}.ctx b{color:var(--tx-0)}
      .se-hero{background:linear-gradient(180deg,#fff,#FCFEFD);border:1px solid var(--cizgi);border-radius:20px;padding:22px 24px;box-shadow:var(--sh);margin-bottom:13px}
      .hq{font-size:12.5px;font-weight:600;color:var(--tx-2);margin-bottom:9px}
      .verdict{font-size:19px;font-weight:750;line-height:1.42;color:var(--tx-0);letter-spacing:-.01em}
      .verdict b{color:var(--yesil)}
      .rt{display:flex;flex-direction:column;gap:13px;margin-top:22px}
      .rt-row{display:grid;grid-template-columns:230px 1fr;gap:18px;align-items:center}
      .rt-lab .nm{font-size:13.5px;font-weight:700;color:var(--tx-0)}
      .rt-lab .nm .frq{color:var(--tx-2);font-weight:600;font-size:11.5px;margin-left:5px}
      .rt-lab .sub{font-size:11px;color:var(--tx-2);margin-top:2px;font-variant-numeric:tabular-nums}
      .rt-bar{position:relative;height:32px}
      .rt-tk{position:absolute;inset:0;background:var(--zemin-2);border-radius:9px}
      .rt-fl{position:absolute;top:0;bottom:0;left:0;border-radius:9px;background:linear-gradient(90deg,#1a936a,var(--yesil));min-width:4px;box-shadow:inset 0 1px 0 rgba(255,255,255,.12)}
      .rt-fl.lo{background:linear-gradient(90deg,#d68a3a,var(--sari))}
      .rt-v{position:absolute;top:50%;transform:translateY(-50%);font-size:15px;font-weight:800;font-variant-numeric:tabular-nums;white-space:nowrap}
      .rt-axis{display:grid;grid-template-columns:230px 1fr;gap:18px;margin-top:4px}
      .rt-axis .ax{position:relative;height:14px;font-size:10px;color:var(--tx-3);font-variant-numeric:tabular-nums}
      .rt-axis .ax span{position:absolute;transform:translateX(-50%)}
      .card{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:18px;padding:20px 22px;box-shadow:var(--sh);margin-bottom:13px}
      .se-h{display:flex;align-items:baseline;gap:2px;margin-bottom:3px;flex-wrap:wrap}
      .se-h .tick{width:4px;height:15px;border-radius:2px;background:var(--yesil);transform:translateY(2px);margin-right:9px}
      .se-h h4{margin:0;font-size:15px;font-weight:800;color:var(--tx-0)}
      .se-sub{font-size:12px;color:var(--tx-1);line-height:1.55;margin:7px 0 4px 13px}.se-sub b{color:var(--tx-0)}
      .ihmal{display:flex;gap:13px;align-items:center;background:var(--kirmizi-z);border:1px solid rgba(196,61,40,.2);border-radius:14px;padding:15px 17px;margin-bottom:13px}
      .ihmal .big{font-size:30px;font-weight:820;color:var(--kirmizi);line-height:1;font-variant-numeric:tabular-nums;flex:0 0 auto}
      .ihmal .tx{font-size:12.5px;line-height:1.5;color:#7a2a1a}.ihmal .tx b{color:#5c1f13}
      .baz{background:var(--mavi-z);border-radius:12px;padding:13px 15px;margin-bottom:13px;font-size:12px;line-height:1.55;color:#1c4f8f}.baz b{color:#123563}
      .baz .row{display:flex;gap:14px;flex-wrap:wrap;margin-top:8px}
      .baz .chip{font-size:11px;background:#fff;border:1px solid rgba(37,99,235,.18);border-radius:999px;padding:3px 10px;color:#1c4f8f;font-weight:600;font-variant-numeric:tabular-nums}
      .how{background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:14px;padding:16px 18px;margin-bottom:13px}
      .how h4{margin:0 0 9px;font-size:13px;font-weight:800;color:var(--tx-1)}
      .how div{font-size:12px;color:var(--tx-1);line-height:1.6;margin-bottom:6px}.how b{color:var(--tx-0)}.how code{background:var(--zemin-2);padding:1px 6px;border-radius:5px;font-size:10.5px}
      .se-foot{padding:13px 15px;background:var(--zemin-0);border:1px solid var(--cizgi);border-radius:12px;font-size:11px;line-height:1.65;color:var(--tx-2)}.se-foot b{color:var(--tx-1)}.se-foot .dot{color:var(--tx-3);margin:0 6px}
      .se-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}
    </style>`;
    const KICK = `<div class="se-kick"><span class="t">📈 Saha ROI · ziyaret sıklığı → tekrar-alım</span><span class="p">son 12 ay</span></div>`;
    const CTX = rep
      ? `<div class="ctx"><span class="ic">📍</span><div>Senin defterinde <b>${kp.matched || 0}</b> aktif müşteri; son 12 ayda <b>${kp.ziyaret_edilmis || 0}'ine</b> (%${Math.round(kp.pct || 0)}) uğramışsın. Aşağıda <b>ne kadar sık ziyaret ettiğin</b> ile müşterinin ${term("geri gelmesi", "H1'de (önceki 6 ay) alan müşterinin H2'de (son 6 ay) de alması. Tutara duyarsız.")} arasındaki ilişki. Az müşterili gruplarda sayı oynak — 'az örnek' etiketine dikkat.</div></div>`
      : `<div class="ctx"><span class="ic">📍</span><div>Saha ekibi <b>${kp.matched || 0}</b> aktif müşterinin <b>${kp.ziyaret_edilmis || 0}'ine</b> (%${Math.round(kp.pct || 0)}) uğramış. Kapsam neredeyse tam olduğundan "ziyaret edilen vs edilmeyen" kıyası kurulamaz (karşı-grup yok) — bunun yerine <b>ziyaret sıklığının</b> ${term("tekrar-alımla", "H1'de (önceki 6 ay) alan müşterinin H2'de (son 6 ay) de alması. Tutara duyarsız, sağlam ölçüt.")} ilişkisine bakıyoruz.</div></div>`;
    const verdict = (g0 && gHi && g0.retention != null && gHi.retention != null)
      ? `Daha sık ziyaret edilen müşteri daha çok geri geliyor: yılda <b>hiç uğranmayanın %${Math.round(g0.retention)}'ı</b> tekrar alırken, <b>${esc(gHi.aralik)} ziyaret edilenin %${Math.round(gHi.retention)}'ı</b> tekrar alıyor.`
      : `Ziyaret sıklığı ile tekrar-alım ilişkisi (aşağıda).`;
    const maxAx = 100;
    const rtRows = gr.map((g) => {
      const az = (g.taban || 0) < AZ;
      const w = g.retention == null ? 0 : Math.max(4, g.retention / maxAx * 100);
      const inside = (g.retention || 0) > 16;
      const vst = inside ? `right:calc(${100 - w}% + 10px);color:#fff` : `left:calc(${w}% + 10px);color:var(--tx-0)`;
      const lo = (g.retention != null && g.retention < 65);
      return `<div class="rt-row">
        <div class="rt-lab"><div class="nm">${esc(g.etiket)}<span class="frq">${esc(g.aralik)} ziyaret/yıl</span></div><div class="sub">${g.taban || 0} müşteri${az ? " · az örnek" : ""}</div></div>
        <div class="rt-bar"><div class="rt-tk"></div><div class="rt-fl ${lo ? "lo" : ""}" style="width:${w}%"></div><span class="rt-v" style="${vst}">${pctR(g.retention)}</span></div></div>`;
    }).join("");
    const AXIS = `<div class="rt-axis"><div></div><div class="ax"><span style="left:0">0%</span><span style="left:50%">50%</span><span style="left:100%">100%</span></div></div>`;
    const HERO = `<div class="se-hero"><div class="hq">Daha çok ziyaret, müşteriyi elde tutuyor mu?</div>
      <div class="verdict">${verdict}</div>
      <div class="rt">${rtRows || `<div class="se-empty">Veri yok</div>`}</div>${gr.length ? AXIS : ""}</div>`;
    const IHMAL = (o.ihmal_n) ? `<div class="ihmal"><div class="big">${o.ihmal_n}</div><div class="tx"><b>${rep ? "müşterine son 12 ayda hiç uğramamışsın." : "müşteri son 12 ayda hiç ziyaret edilmemiş."}</b> Ortalama yıllık cirosu <b>${kTL(o.ihmal_ort_ciro)}</b>, tekrar-alımı yalnız <b>%${Math.round(o.ihmal_retention || 0)}</b> — en riskli cep. ${rep ? "Sabah Rotam ve Kapsam'da tek tek görünür." : "(Kapsam raporunda tek tek görünür.)"}</div></div>` : "";
    const bazChips = withT.map((g) => `<span class="chip">${esc(g.aralik)}: ${kTL(g.ort_ciro)}</span>`).join("");
    const BAZ = `<div class="baz"><b>⚖️ Kıyas adil mi?</b> Bu bir <b>korelasyondur</b>, nedensellik değil — sık ziyaret edilen müşteriler zaten daha büyük/bağlı olabilir. Grupların öncesi ortalama cirosu (aşağıda) farklıysa etkiyi tek başına ziyarete yıkma.<div class="row">${bazChips}</div></div>`;
    const HOW = `<div class="how"><h4>Nasıl hesaplanıyor?</h4>
      <div><b>Ziyaret sıklığı</b> = son 12 ayda tamamlanmış ziyaret sayısı; müşteriler 0 / 1-3 / 4-8 / 9+ gruplarına ayrılır.</div>
      <div><b>Tekrar-alım</b> = önceki 6 ayda (H1) alan müşterilerin, son 6 ayda (H2) da alma oranı. Ciro <b>tutarına duyarsız</b> — bir kişi bir kez bile alsa "geri geldi" sayılır; bu yüzden birkaç dev müşteri ya da düzensiz alım sonucu bozmaz.</div>
      <div>Eşleşme müşteri koduyla (<code>musteri_kodu</code>); yalnız H1'de alan müşteriler paydaya girer. Ciro <b>büyümesi</b> KRB'de birkaç büyük müşteri + düzensiz alımla çok dağınık olduğundan manşet yapılmadı.</div></div>`;
    const FOOT = `<div class="se-foot"><b>Genel tekrar-alım %${Math.round(o.genel_retention || 0)}</b> (${o.taban_toplam || 0} müşteri paydada)<span class="dot">·</span>Sıklık dönemi ${dn.yil ? dn.yil.join(" → ") : "—"}<span class="dot">·</span>H1 ${dn.h1 ? dn.h1.join(" → ") : "—"}<span class="dot">·</span>H2 ${dn.h2 ? dn.h2.join(" → ") : "—"}. Veri sonu ${dn.veri_sonu || "—"}.</div>`;
    box.innerHTML = CSS + `<div class="se">${KICK}${CTX}${HERO}${IHMAL}${BAZ}${HOW}${FOOT}</div>`;
  }
'''

KAP = "  async function rpKapsam() {  /* KAPSAM_DK_V1 */"
if "  async function rpEtki()" in s:
    a = s.index("  async function rpEtki()")
    b = s.index(KAP, a)
    s = s[:a] + NEWFN + s[b:]
else:
    assert s.count(KAP) == 1, "rpKapsam anchor=%d" % s.count(KAP)
    s = s.replace(KAP, NEWFN + KAP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_ETKI_DK_V1 (masaustu · retention · upsert)")
