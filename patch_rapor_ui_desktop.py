# -*- coding: utf-8 -*-
# RAPOR_UI_DK_V1 (masaüstü) — Rapor › Özet Phase C: mobil ile birebir görsel dil.
#   Tek palet + nötr sayılar, hero (Tamamlanan Ziyaret + delta + sparkline), birleşik .rpc-tile,
#   kapsam metresi, Win pill, her kutuda ⓘ tooltip. Mevcut delta/_priorRange KORUNUR.
#   Drill id'leri (rp-oz-*, rp-tk-*, rp-yeni-mus) ve handler'lar dokunulmaz.
#   Yeni Müşteri etiketi gerçek tanıma göre ("Yeni Müşteri", toplu yüklemeler hariç).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_UI_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

i0 = s.index("  async function rpOzet() {")

# ── Edit A: yardımcılar (spark, tooltip, tile) — _dcls satırından sonra ──
ANCH_A = '  const _dcls = (d, inv) => !d ? "" : d.dir === "neu" ? "neu" : ((d.dir === "up") !== !!inv ? "up" : "dn");'
assert s.count(ANCH_A) == 1, "A anchor=%d" % s.count(ANCH_A)
HELP = ANCH_A + r"""
  const _rpSpark = (arr) => {
    const w = 520, h = 60, pad = 3;
    if (!arr || arr.length < 2) return "";
    const mx = Math.max(...arr), mn = Math.min(...arr), iw = w - pad * 2, ih = h - pad * 2;
    const pts = arr.map((v, i) => [pad + (i / (arr.length - 1)) * iw, pad + ih - ((v - mn) / ((mx - mn) || 1)) * ih]);
    const d = pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
    const area = d + " L " + (w - pad) + " " + (h - pad) + " L " + pad + " " + (h - pad) + " Z";
    const lp = pts[pts.length - 1];
    return `<svg width="100%" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" style="display:block"><defs><linearGradient id="rpcgd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2563eb" stop-opacity=".18"/><stop offset="1" stop-color="#2563eb" stop-opacity="0"/></linearGradient></defs><path d="${area}" fill="url(#rpcgd)"/><path d="${d}" fill="none" stroke="#2563eb" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/><circle cx="${lp[0].toFixed(1)}" cy="${lp[1].toFixed(1)}" r="3.4" fill="#2563eb" stroke="#fff" stroke-width="1.6"/></svg>`;
  };
  const _rpTips = (root) => {
    let tp = document.getElementById("rpc-tip");
    if (!tp) { tp = document.createElement("div"); tp.id = "rpc-tip"; tp.className = "rpc-tip"; document.body.appendChild(tp); document.addEventListener("click", () => tp.classList.remove("show")); }
    const place = (t) => { const r = t.getBoundingClientRect(); tp.style.left = Math.max(8, Math.min(window.innerWidth - tp.offsetWidth - 8, r.left)) + "px"; let top = r.bottom + 8; if (top + tp.offsetHeight > window.innerHeight - 8) top = r.top - tp.offsetHeight - 8; tp.style.top = top + "px"; };
    root.querySelectorAll("[data-tip]").forEach((elx) => {
      let q = elx.querySelector(".rpc-qi");
      if (!q) { q = document.createElement("span"); q.className = "rpc-qi"; q.textContent = "i"; elx.appendChild(q); }
      const show = () => { tp.innerHTML = elx.getAttribute("data-tip"); tp.classList.add("show"); place(q); };
      q.addEventListener("mouseenter", show);
      q.addEventListener("mouseleave", () => tp.classList.remove("show"));
      q.addEventListener("click", (ev) => { ev.stopPropagation(); if (tp.classList.contains("show")) tp.classList.remove("show"); else show(); });
    });
  };
  const _dtile = (id, val, label, tip, d, inv, clk) =>
    `<div class="rpc-tile${clk ? " tik" : ""}"${id ? ` id="${id}"` : ""}${tip ? ` data-tip="${esc(tip)}"` : ""}${clk ? ` title="${esc(clk)}"` : ""}><div class="rpc-num">${val == null ? "—" : val}</div><div class="rpc-lbl">${esc(label)}</div>${d ? `<div class="rpc-chip ${_dcls(d, inv)}">${esc(d.txt)}</div>` : ""}</div>`;"""
s = s.replace(ANCH_A, HELP, 1)

# ── Edit B: innerHTML (yeni tasarım) + tooltip wiring ──
i0 = s.index("  async function rpOzet() {")
a = s.index("    el2.innerHTML = `", i0)
b = s.index("</div></details>\n    </div>`;", a) + len("</div></details>\n    </div>`;")
NEW = r"""    el2.innerHTML = `<!--RAPOR_UI_DK_V1-->
      <style>
      .rpc-dwrap{padding:2px 0}
      .rpc-drow{display:grid;grid-template-columns:1.4fr 1fr;gap:14px;align-items:stretch}
      @media(max-width:820px){.rpc-drow{grid-template-columns:1fr}}
      .rpc-hero{position:relative;background:#fff;border:1px solid #e8edf3;border-radius:16px;padding:18px;box-shadow:0 1px 3px rgba(15,23,42,.06)}
      .rpc-hero.tik{cursor:pointer}.rpc-hero.tik:hover{border-color:#cfdcf5}
      .rpc-hero-top{display:flex;justify-content:space-between;align-items:flex-start;gap:10px}
      .rpc-hero-lbl{font-size:12px;font-weight:600;color:#475569}
      .rpc-hero-num{font-size:40px;font-weight:800;letter-spacing:-.02em;line-height:1.05;margin-top:2px;color:#0f172a}
      .rpc-hero-num small{font-size:15px;font-weight:600;color:#94a3b8;margin-left:5px}
      .rpc-delta{display:inline-flex;align-items:center;gap:3px;font-size:12px;font-weight:700;padding:3px 9px;border-radius:999px;white-space:nowrap}
      .rpc-delta.up{color:#16a34a;background:#ecfdf3}.rpc-delta.dn{color:#dc2626;background:#fef2f2}.rpc-delta.neu{color:#64748b;background:#f1f5f9}
      .rpc-spark{margin-top:12px}
      .rpc-sec{position:relative;font-size:11px;font-weight:800;color:#475569;text-transform:uppercase;letter-spacing:.06em;margin:18px 2px 9px;display:flex;align-items:center;gap:7px}
      .rpc-sec::before{content:"";width:3px;height:13px;border-radius:2px;background:#2563eb}
      .rpc-sec .rpc-qi{position:static;margin-left:2px}
      .rpc-grid{display:grid;gap:10px}.rpc-grid.g4{grid-template-columns:repeat(4,1fr)}.rpc-grid.g3{grid-template-columns:repeat(3,1fr)}
      @media(max-width:820px){.rpc-grid.g4{grid-template-columns:repeat(2,1fr)}}
      .rpc-tile{position:relative;background:#fff;border:1px solid #e8edf3;border-radius:13px;padding:12px 13px;box-shadow:0 1px 3px rgba(15,23,42,.05)}
      .rpc-tile.tik{cursor:pointer;transition:border-color .12s,transform .12s}.rpc-tile.tik:hover{border-color:#cfdcf5;transform:translateY(-1px)}
      .rpc-num{font-size:24px;font-weight:800;color:#0f172a;line-height:1}
      .rpc-lbl{font-size:11.5px;color:#475569;margin-top:6px;font-weight:500}
      .rpc-chip{display:inline-block;margin-top:7px;font-size:11px;font-weight:700;padding:2px 7px;border-radius:999px}
      .rpc-chip.up{color:#16a34a;background:#ecfdf3}.rpc-chip.dn{color:#dc2626;background:#fef2f2}.rpc-chip.neu{color:#64748b;background:#f1f5f9}
      .rpc-meter{position:relative;background:#fff;border:1px solid #e8edf3;border-radius:16px;padding:16px;box-shadow:0 1px 3px rgba(15,23,42,.05);display:flex;flex-direction:column;justify-content:center}
      .rpc-mtop{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:9px}
      .rpc-mtop .t{font-size:13px;font-weight:700;color:#0f172a}.rpc-mtop .v{font-size:12px;color:#475569;font-weight:600}
      .rpc-track{height:12px;background:#f1f5f9;border-radius:7px;overflow:hidden}.rpc-fill{height:100%;border-radius:7px}
      .rpc-note{font-size:12px;color:#475569;margin-top:9px;line-height:1.5}
      .rpc-pill{position:relative;display:inline-flex;align-items:center;gap:5px;font-size:13px;font-weight:700;padding:5px 12px;border-radius:999px}
      .rpc-pill.good{color:#16a34a;background:#ecfdf3}.rpc-pill.warn{color:#d97706;background:#fff7ed}
      .rpc-rev{position:relative;background:linear-gradient(180deg,#f6faf7,#eefaf1);border:1px solid #cdeede;border-radius:13px;padding:12px 15px;display:flex;justify-content:space-between;align-items:center;gap:12px}
      .rpc-rev .l{font-size:12px;color:#16a34a;font-weight:700}.rpc-rev .n{font-size:20px;font-weight:800;color:#15803d}
      .rpc-qi{position:absolute;top:9px;right:9px;width:16px;height:16px;border-radius:50%;background:#eef2f7;color:#94a3b8;font-size:10px;font-weight:800;display:inline-flex;align-items:center;justify-content:center;cursor:help;z-index:2;line-height:1}
      .rpc-pill .rpc-qi{position:static;width:13px;height:13px;margin-left:2px;background:transparent;color:currentColor;opacity:.7}
      .rpc-tip{position:fixed;max-width:260px;background:#0f172a;color:#f8fafc;font-size:12px;font-weight:500;line-height:1.5;padding:9px 11px;border-radius:9px;box-shadow:0 8px 28px rgba(15,23,42,.32);z-index:9999;opacity:0;pointer-events:none;transition:opacity .12s}
      .rpc-tip.show{opacity:1}.rpc-tip b{color:#93c5fd}
      </style>
      <div class="rpc-dwrap">
        <div class="rpc-drow">
          <div class="rpc-hero tik" id="rp-oz-ziyaret" data-tip="Tamamlanan Ziyaret: dönemde durumu TAMAMLANDI olan ziyaret. Aynı müşteriye 2 ziyaret = 2 sayılır." title="Ziyaretleri listele">
            <div class="rpc-hero-top">
              <div><div class="rpc-hero-lbl">Tamamlanan Ziyaret · dönem</div><div class="rpc-hero-num">${o.toplam_ziyaret || 0}<small>ziyaret</small></div></div>
              ${(() => { const dz = _delta(o.toplam_ziyaret, po.toplam_ziyaret); return dz ? `<span class="rpc-delta ${_dcls(dz)}">${esc(dz.txt)}</span>` : ""; })()}
            </div>
            ${(ozet.gunluk && ozet.gunluk.length > 1) ? `<div class="rpc-spark">${_rpSpark(ozet.gunluk.map(g => Number(g.ziyaret) || 0))}</div>` : ""}
          </div>
          ${(() => { const pf = Number(o.portfoy || 0), ul = Number(o.benzersiz_nokta || 0), pct = pf ? Math.min(100, Math.round(100 * ul / pf)) : 0, cc = pct >= 60 ? "#16a34a" : pct >= 30 ? "#2563eb" : "#d97706"; return `<div class="rpc-meter" data-tip="Portföy Kapsamı: Ulaşılan Müşteri ÷ Portföy. Yeşil ≥%60, mavi ≥%30, amber <%30.">
            <div class="rpc-mtop"><span class="t">📍 Portföy Kapsamı</span><span class="v">${ul} / ${pf} müşteri</span></div>
            <div class="rpc-track"><div class="rpc-fill" style="width:${pct}%;background:${cc}"></div></div>
            <div class="rpc-note">Dönemde portföyün <b style="color:${cc}">%${pct}</b>'ine ulaşıldı${pf && ul < pf ? ` · <b>${pf - ul}</b> müşteri hiç ziyaret edilmedi` : ""}.</div>
          </div>`; })()}
        </div>

        <div class="rpc-sec" data-tip="Oklar önceki eşit döneme göre değişimi gösterir.">Genel Bakış</div>
        <div class="rpc-grid g4">
          ${_dtile(null, o.planlanan, "Planlanan", "Planlanan: planlanmış ama henüz tamamlanmamış ziyaret (durum = PLANLANDI).")}
          ${_dtile("rp-oz-benzersiz", o.benzersiz_nokta, "Ulaşılan Müşteri", "Ulaşılan Müşteri: dönemde en az 1 ziyaret yapılan FARKLI müşteri.", _delta(o.benzersiz_nokta, po.benzersiz_nokta), false, "Ulaşılan müşterileri listele")}
          ${_dtile("rp-oz-yeni", o.yeni_nokta, "Yeni Müşteri Ziyareti", "Yeni Müşteri Ziyareti: durumu 'Yeni Nokta' müşterilere ziyaret (edinim değil).", _delta(o.yeni_nokta, po.yeni_nokta), false, "Yeni müşteri ziyaretlerini listele")}
          ${_dtile("rp-oz-pasif", o.pasif_riskli, "Yeniden Kazanım", "Yeniden Kazanım: durumu Pasif/Eski/Riskli müşterilere ziyaret.", _delta(o.pasif_riskli, po.pasif_riskli), true, "Yeniden kazanım ziyaretlerini listele")}
        </div>

        <div class="rpc-sec">Teklif Özeti</div>
        <div class="rpc-grid g4">
          ${_dtile("rp-tk-toplam", t.toplam, "Toplam", "Toplam Teklif: dönemde oluşturulan tüm teklifler.", _delta(t.toplam, ptk.toplam), false, "Tüm teklifleri listele")}
          ${_dtile("rp-tk-kaz", t.kazanilan, "Kazanılan", "Kazanılan: KAZANILDI teklif adedi.", _delta(t.kazanilan, ptk.kazanilan), false, "Kazanılan teklifleri listele")}
          ${_dtile("rp-tk-kayb", t.kaybedilen, "Kaybedilen", "Kaybedilen: KAYBEDILDI teklif adedi.", _delta(t.kaybedilen, ptk.kaybedilen), true, "Kaybedilen teklifleri listele")}
          ${_dtile("rp-tk-acik", t.bekleyen, "Açık", "Açık: henüz sonuçlanmamış teklifler.", null, false, "Açık teklifleri listele")}
        </div>
        <div style="display:flex;align-items:center;gap:14px;justify-content:flex-end;margin-top:10px;flex-wrap:wrap">
          <span class="rpc-pill ${winRate != null && winRate >= 50 ? "good" : "warn"}" data-tip="Win Rate: Kazanılan ÷ (Kazanılan + Kaybedilen). Açık teklifler paydaya girmez.">● Win ${winRate != null ? "%" + winRate : "—"}</span>
          ${kazTutar ? `<div class="rpc-rev" data-tip="Kazanılan Ciro: durumu KAZANILDI tekliflerin toplam ₺ tutarı."><span class="l">Kazanılan Ciro</span><span class="n">${money(kazTutar)}</span></div>` : ""}
        </div>

        ${isMgr && yeniMus && yeniMus.ozet ? (() => { const oz = yeniMus.ozet; return `
        <div class="rpc-sec">Yeni Müşteri</div>
        <div class="rpc-grid g3">
          <div class="rpc-tile tik" id="rp-yeni-mus" data-tip="Yeni Müşteri: ilk ziyareti UYGULAMADAN girilen ve Excel yüklemesinde OLMAYAN gerçek yeni saha müşterisi (dönemde). Toplu yüklenen müşteriler sayılmaz." title="Yeni müşterileri listele"><div class="rpc-num" style="color:#16a34a">${oz.toplam}</div><div class="rpc-lbl">Yeni Müşteri</div></div>
          ${_dtile(null, oz.konumlu, "GPS Pinli", "GPS Pinli: konumu kaydedilmiş yeni müşteri.")}
          ${_dtile(null, oz.vkn_var, "VKN Girilen", "VKN Girilen: vergi kimlik numarası girilmiş yeni müşteri.")}
        </div>`; })() : ""}

        <div class="rpc-tanim" style="margin-top:16px;background:#fff;border:1px solid #e8edf3;border-radius:13px;padding:2px 14px">
          <details><summary style="cursor:pointer;font-size:13px;font-weight:700;padding:11px 0;color:#374151">ⓘ Tüm tanımlar</summary>
          <div style="font-size:12.5px;color:#475569;line-height:1.8;padding-bottom:12px">
            <div><b>Tamamlanan Ziyaret:</b> durumu TAMAMLANDI ziyaret (aynı müşteriye 2 = 2).</div>
            <div><b>Planlanan:</b> planlanmış ama tamamlanmamış ziyaret.</div>
            <div><b>Ulaşılan Müşteri:</b> dönemde ≥1 ziyaret yapılan farklı müşteri.</div>
            <div><b>Yeni Müşteri Ziyareti:</b> 'Yeni Nokta' müşterilere ziyaret.</div>
            <div><b>Yeniden Kazanım:</b> Pasif/Eski/Riskli müşterilere ziyaret.</div>
            <div><b>Yeni Müşteri:</b> ilk ziyareti uygulamadan girilen, Excel'de olmayan gerçek yeni müşteri.</div>
            <div><b>Win Rate:</b> Kazanılan ÷ (Kazanılan + Kaybedilen).</div>
            <div style="margin-top:7px;padding-top:7px;border-top:1px dashed #e8edf3"><b>Durum</b> (Yeni/Aktif/Pasif/Eski/Riskli) ERP satışından otomatik türetilir; kartın arşiv durumundan farklıdır.</div>
          </div></details>
        </div>
      </div>`;
      _rpTips(el2);"""
s = s[:a] + NEW + s[b:]

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_UI_DK_V1 (masaüstü)")
