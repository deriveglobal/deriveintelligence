# -*- coding: utf-8 -*-
# RAPOR_UI_V1 (mobil) — Rapor › Özet görsel birleştirme (Phase C):
#   tek palet + nötr sayılar, hero (Tamamlanan Ziyaret + delta + sparkline),
#   birleşik tile bileşeni, kapsam metresi, Win pill, her kutuda ⓘ tooltip.
#   Drill id'leri (rp-oz-*) ve rp-buhafta / Tanımlar KORUNUR. Handler'lar dokunulmaz.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_UI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

i0 = s.index("  async function rpOzet() {")

# ── Edit 1: veri çekimi + önceki dönem (delta) ──
NEW1 = r"""      const _f = rpFrom(), _t = rpTo(), _MS = 86400000;
      const _dF = new Date(_f), _dT = new Date(_t);
      const _len = Math.max(1, Math.round((_dT - _dF) / _MS) + 1);
      const _pT = new Date(_dF.getTime() - _MS), _pF = new Date(_dF.getTime() - _len * _MS);
      const _isoD = (d) => d.toISOString().slice(0, 10);
      const reqs = [
        api(`/api/saha/rapor/ozet?from=${_f}&to=${_t}${tipQS()}`),
        api(`/api/saha/rapor/teklif?from=${_f}&to=${_t}${tipQS()}`),
        api(`/api/saha/rapor/ozet?from=${_isoD(_pF)}&to=${_isoD(_pT)}${tipQS()}`).catch(() => null)
      ];
      if (isMgr) reqs.push(api(`/api/saha/admin/yeni-musteriler?from=${_f}&to=${_t}${tipQS()}`));
      const [ozet, teklif, ozetPrev, yeniMus] = await Promise.all(reqs);"""
a = s.index("      const reqs = [", i0)
b = s.index("await Promise.all(reqs);", a) + len("await Promise.all(reqs);")
s = s[:a] + NEW1 + s[b:]
i1 = a + len(NEW1)

# ── Edit 2: türetilmiş değişkenler + yardımcılar (spark/tile/tooltip) ──
NEW2 = r"""      const el2 = icerik(); if (!el2) return;

      const o   = ozet.ozet;
      const to_ = teklif.ozet;
      const gunluk = ozet.gunluk || [];
      const sonuclanan = Number(to_.kazanilan) + Number(to_.kaybedilen);
      const winRate    = sonuclanan ? Math.round(1000 * to_.kazanilan / sonuclanan) / 10 : null;
      const kazTutar   = Number(to_.kazanilan_tutar || 0);
      const pf = Number(o.portfoy || 0), ul = Number(o.benzersiz_nokta || 0);
      const cov = pf ? Math.min(100, Math.round(100 * ul / pf)) : 0;
      const covCol = cov >= 60 ? "#16a34a" : cov >= 30 ? "#2563eb" : "#d97706";
      const _cur = Number(o.toplam_ziyaret || 0);
      const _prev = (ozetPrev && ozetPrev.ozet) ? Number(ozetPrev.ozet.toplam_ziyaret || 0) : null;
      const _delta = (_prev != null && _prev > 0) ? Math.round(100 * (_cur - _prev) / _prev) : null;

      const _rpSpark = (arr) => {
        const w = 340, h = 46, pad = 3;
        if (!arr || arr.length < 2) return "";
        const mx = Math.max(...arr), mn = Math.min(...arr), iw = w - pad * 2, ih = h - pad * 2;
        const pts = arr.map((v, i) => [pad + (i / (arr.length - 1)) * iw, pad + ih - ((v - mn) / ((mx - mn) || 1)) * ih]);
        const d = pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
        const area = d + " L " + (w - pad) + " " + (h - pad) + " L " + pad + " " + (h - pad) + " Z";
        const lp = pts[pts.length - 1];
        return `<svg width="100%" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" style="display:block"><defs><linearGradient id="rpcg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2563eb" stop-opacity=".18"/><stop offset="1" stop-color="#2563eb" stop-opacity="0"/></linearGradient></defs><path d="${area}" fill="url(#rpcg)"/><path d="${d}" fill="none" stroke="#2563eb" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/><circle cx="${lp[0].toFixed(1)}" cy="${lp[1].toFixed(1)}" r="3.2" fill="#2563eb" stroke="#fff" stroke-width="1.5"/></svg>`;
      };
      const _tile = (id, val, label, dot, tip) =>
        `<div class="rpc-tile"${id ? ` id="${id}"` : ""}${tip ? ` data-tip="${esc(tip)}"` : ""}><div class="rpc-num">${val || 0}</div><div class="rpc-lbl">${dot ? `<span class="rpc-dot ${dot}"></span>` : ""}${label}</div></div>`;
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
      };"""
a = s.index("      const el2 = icerik(); if (!el2) return;", i1)
b = s.index("</div>`;", a) + len("</div>`;")
s = s[:a] + NEW2 + s[b:]
i2 = a + len(NEW2)

# ── Edit 3: innerHTML (yeni tasarım) + tooltip wiring ──
NEW3 = r"""      el2.innerHTML = `<!--RAPOR_UI_V1-->
        <style>
        .rpc-wrap{padding:2px 0}
        .rpc-hero{position:relative;background:#fff;border:1px solid #e8edf3;border-radius:14px;padding:15px;box-shadow:0 1px 3px rgba(15,23,42,.06);cursor:pointer}
        .rpc-hero-top{display:flex;justify-content:space-between;align-items:flex-start;gap:8px}
        .rpc-hero-lbl{font-size:12px;font-weight:600;color:#475569}
        .rpc-hero-num{font-size:34px;font-weight:800;letter-spacing:-.02em;line-height:1.05;margin-top:2px;color:#0f172a}
        .rpc-hero-num small{font-size:14px;font-weight:600;color:#94a3b8;margin-left:4px}
        .rpc-delta{display:inline-flex;align-items:center;gap:3px;font-size:12px;font-weight:700;padding:3px 8px;border-radius:999px;white-space:nowrap}
        .rpc-delta.up{color:#16a34a;background:#ecfdf3}.rpc-delta.down{color:#dc2626;background:#fef2f2}
        .rpc-spark{margin-top:10px}
        .rpc-sec{font-size:11px;font-weight:800;color:#475569;text-transform:uppercase;letter-spacing:.05em;margin:16px 2px 8px;display:flex;align-items:center;gap:6px}
        .rpc-sec::before{content:"";width:3px;height:12px;border-radius:2px;background:#2563eb}
        .rpc-grid{display:grid;gap:8px}.rpc-grid.g2{grid-template-columns:repeat(2,1fr)}.rpc-grid.g4{grid-template-columns:repeat(4,1fr)}
        .rpc-tile{position:relative;background:#fff;border:1px solid #e8edf3;border-radius:12px;padding:10px 11px;box-shadow:0 1px 3px rgba(15,23,42,.05);cursor:pointer}
        .rpc-tile:active{transform:scale(.99)}
        .rpc-num{font-size:21px;font-weight:800;color:#0f172a;line-height:1}
        .rpc-lbl{font-size:10.5px;color:#475569;margin-top:5px;font-weight:500;display:flex;align-items:center;gap:5px}
        .rpc-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0}
        .rpc-dot.p{background:#64748b}.rpc-dot.u{background:#0891b2}.rpc-dot.n{background:#16a34a}.rpc-dot.k{background:#d97706}
        .rpc-meter{position:relative;background:#fff;border:1px solid #e8edf3;border-radius:14px;padding:13px;box-shadow:0 1px 3px rgba(15,23,42,.05);margin-top:10px}
        .rpc-mtop{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px}
        .rpc-mtop .t{font-size:13px;font-weight:700;color:#0f172a}.rpc-mtop .v{font-size:12px;color:#475569;font-weight:600}
        .rpc-track{height:11px;background:#f1f5f9;border-radius:6px;overflow:hidden}.rpc-fill{height:100%;border-radius:6px}
        .rpc-note{font-size:11px;color:#475569;margin-top:7px;line-height:1.5}
        .rpc-pill{position:relative;display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:700;padding:4px 10px;border-radius:999px}
        .rpc-pill.good{color:#16a34a;background:#ecfdf3}.rpc-pill.warn{color:#d97706;background:#fff7ed}
        .rpc-rev{position:relative;margin-top:9px;background:linear-gradient(180deg,#f6faf7,#eefaf1);border:1px solid #cdeede;border-radius:12px;padding:11px 13px;display:flex;justify-content:space-between;align-items:center}
        .rpc-rev .l{font-size:12px;color:#16a34a;font-weight:700}.rpc-rev .n{font-size:18px;font-weight:800;color:#15803d}
        .rpc-qi{position:absolute;top:7px;right:7px;width:16px;height:16px;border-radius:50%;background:#eef2f7;color:#94a3b8;font-size:10px;font-weight:800;display:inline-flex;align-items:center;justify-content:center;cursor:help;z-index:2;line-height:1}
        .rpc-pill .rpc-qi{position:static;width:13px;height:13px;margin-left:1px;background:transparent;color:currentColor;opacity:.7}
        .rpc-tip{position:fixed;max-width:240px;background:#0f172a;color:#f8fafc;font-size:12px;font-weight:500;line-height:1.5;padding:8px 10px;border-radius:9px;box-shadow:0 6px 24px rgba(15,23,42,.3);z-index:9999;opacity:0;pointer-events:none;transition:opacity .12s}
        .rpc-tip.show{opacity:1}.rpc-tip b{color:#93c5fd}
        </style>
        <div class="rpc-wrap">
          <div id="rp-buhafta"></div>
          <div class="rpc-hero" id="rp-oz-ziyaret" data-tip="Tamamlanan Ziyaret: dönemde durumu TAMAMLANDI olan ziyaret. Aynı müşteriye 2 ziyaret = 2 sayılır.">
            <div class="rpc-hero-top">
              <div><div class="rpc-hero-lbl">Tamamlanan Ziyaret · dönem</div><div class="rpc-hero-num">${_cur}<small>ziyaret</small></div></div>
              ${_delta != null ? `<span class="rpc-delta ${_delta >= 0 ? "up" : "down"}">${_delta >= 0 ? "▲" : "▼"} %${Math.abs(_delta)}</span>` : ""}
            </div>
            ${gunluk.length > 1 ? `<div class="rpc-spark">${_rpSpark(gunluk.map(g => Number(g.ziyaret) || 0))}</div>` : ""}
          </div>

          <div class="rpc-sec">Genel Bakış</div>
          <div class="rpc-grid g2">
            ${_tile("", o.planlanan, "Planlanan", "p", "Planlanan: planlanmış ama henüz tamamlanmamış ziyaret (durum = PLANLANDI).")}
            ${_tile("rp-oz-benzersiz", o.benzersiz_nokta, "Ulaşılan Müşteri", "u", "Ulaşılan Müşteri: dönemde en az 1 ziyaret yapılan FARKLI müşteri sayısı.")}
            ${_tile("rp-oz-yeni", o.yeni_nokta, "Yeni Müşteri Ziyareti", "n", "Yeni Müşteri Ziyareti: durumu 'Yeni Nokta' olan müşterilere yapılan ziyaret (edinim değil, ziyaret sayısı).")}
            ${_tile("rp-oz-pasif", o.pasif_riskli, "Yeniden Kazanım", "k", "Yeniden Kazanım: durumu Pasif/Eski/Riskli müşterilere yapılan ziyaret.")}
          </div>

          <div class="rpc-meter" data-tip="Portföy Kapsamı: Ulaşılan Müşteri ÷ Portföy. Yeşil ≥%60, mavi ≥%30, amber <%30.">
            <div class="rpc-mtop"><span class="t">📍 Portföy Kapsamı</span><span class="v">${ul} / ${pf} müşteri</span></div>
            <div class="rpc-track"><div class="rpc-fill" style="width:${cov}%;background:${covCol}"></div></div>
            <div class="rpc-note">Dönemde portföyün <b style="color:${covCol}">%${cov}</b>'ine ulaşıldı${pf && ul < pf ? ` · <b>${pf - ul}</b> müşteri hiç ziyaret edilmedi` : ""}.</div>
          </div>

          <div class="rpc-sec">Teklif Özeti</div>
          <div class="rpc-grid g4">
            ${_tile("rp-oz-tk-toplam", to_.toplam, "Toplam", "", "Toplam Teklif: dönemde oluşturulan tüm teklif adedi.")}
            ${_tile("rp-oz-tk-kaz", to_.kazanilan, "Kazanılan", "", "Kazanılan: durumu KAZANILDI teklif adedi.")}
            ${_tile("rp-oz-tk-kayb", to_.kaybedilen, "Kaybedilen", "", "Kaybedilen: durumu KAYBEDILDI teklif adedi.")}
            ${_tile("rp-oz-tk-acik", to_.bekleyen, "Açık", "", "Açık: henüz sonuçlanmamış (kazanılmadı/kaybedilmedi/iptal olmadı) teklifler.")}
          </div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-top:9px">
            <span style="font-size:12px;color:#475569;font-weight:600">Kazanma oranı</span>
            <span class="rpc-pill ${winRate != null && winRate >= 50 ? "good" : "warn"}" data-tip="Win Rate: Kazanılan ÷ (Kazanılan + Kaybedilen). Açık teklifler paydaya girmez.">● Win ${winRate != null ? "%" + winRate : "—"}</span>
          </div>
          ${kazTutar ? `<div class="rpc-rev" data-tip="Kazanılan Ciro: durumu KAZANILDI tekliflerin toplam ₺ tutarı."><span class="l">Kazanılan Ciro</span><span class="n">${kazTutar.toLocaleString("tr-TR")}₺</span></div>` : ""}

          ${isMgr && yeniMus ? (() => { const oz = yeniMus.ozet; return `
          <div class="rpc-sec">Yeni Müşteri</div>
          <div class="rpc-grid g4">
            <div class="rpc-tile" id="rp-yeni-mus-kut" data-tip="Yeni Kayıt: dönemde sisteme ilk kez eklenen FARKLI müşteri (gerçek yeni edinim)."><div class="rpc-num" style="color:#16a34a">${oz.toplam}</div><div class="rpc-lbl">Yeni Kayıt</div></div>
            ${_tile("", oz.konumlu, "GPS Pinli", "", "GPS Pinli: konumu kaydedilmiş yeni müşteri.")}
            ${_tile("", oz.vkn_var, "VKN Girilen", "", "VKN Girilen: vergi kimlik numarası girilmiş yeni müşteri.")}
          </div>` ; })() : ""}

          <details class="rpc-tanim" style="margin-top:14px;border:1px solid #e8edf3;border-radius:12px;background:#fff">
            <summary style="cursor:pointer;padding:11px 12px;font-size:12px;font-weight:700;color:#374151">ⓘ Tüm tanımlar</summary>
            <div style="padding:0 12px 12px;font-size:12px;color:#475569;line-height:1.7">
              <div><b>Tamamlanan Ziyaret:</b> durumu TAMAMLANDI ziyaret (aynı müşteriye 2 = 2).</div>
              <div><b>Planlanan:</b> planlanmış ama tamamlanmamış ziyaret.</div>
              <div><b>Ulaşılan Müşteri:</b> dönemde ≥1 ziyaret yapılan farklı müşteri.</div>
              <div><b>Yeni Müşteri Ziyareti:</b> 'Yeni Nokta' müşterilere ziyaret.</div>
              <div><b>Yeniden Kazanım:</b> Pasif/Eski/Riskli müşterilere ziyaret.</div>
              <div><b>Portföy Kapsamı:</b> Ulaşılan ÷ Portföy (%).</div>
              <div><b>Win Rate:</b> Kazanılan ÷ (Kazanılan + Kaybedilen).</div>
              <div style="margin-top:7px;padding-top:7px;border-top:1px dashed #e8edf3"><b>Durum</b> (Yeni/Aktif/Pasif/Eski/Riskli) ERP satışından otomatik türetilir; kartın arşiv durumundan farklıdır.</div>
            </div>
          </details>
        </div>`;
      _rpTips(el2);"""
a = s.index("      el2.innerHTML = `", i2)
b = s.index("</details>\n        </div>`;", a) + len("</details>\n        </div>`;")
s = s[:a] + NEW3 + s[b:]

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_UI_V1 (mobil)")
