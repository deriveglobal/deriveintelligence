#!/usr/bin/env python3
# FAZD_OWNERLENS — mobil Kokpit'i owner-lens sirasina yeniden dizer (vKokpitMobil TAM degisim).
#   (1) Dikkat -> (2) Nabiz: para(Ciro/Marj donem) + NAKIT(DSO/Gecikmis su an) + Iki-Is -> (3) Nakit derinligi
#   (vade + gecikme kaynagi + simulasyon) -> (4) Kirilim (Marka/Segment/Kanal/Sezon/Radar/Icgoru/Stok) KATLI.
#   Finansal Icgoru AI-anlatisi (icgoruler + uydurma ₺ etki) CIKAR; deterministik koken + simulasyon KALIR.
#   Onkosul: FAZB_KOKPIT + FAZC_TOGGLE. Tum veri kaynaklari korunur.
import sys, io
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "FAZD_OWNERLENS" in s:
    print("[skip] FAZD_OWNERLENS zaten var"); sys.exit(0)
if "FAZC_TOGGLE" not in s:
    print("HATA: once FAZC_TOGGLE uygulanmali"); sys.exit(1)

start = s.index("async function vKokpitMobil() {")
ceo = s.index("// CEO_MOBIL_V1", start)
span_end = s.rindex("}", start, ceo) + 1

NEW = r'''async function vKokpitMobil() { /* FAZD_OWNERLENS */
  const m = main();
  m.innerHTML = `<div class="kok-wrap"><div class="mini-durum" style="padding:14px">Kokpit yükleniyor…</div></div>`;
  const money = v => (v == null) ? "—" : Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 1 }) + " M₺";
  const pct = v => (v == null) ? "—" : "%" + Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 1 });
  const mjc = v => v == null ? "#94a3b8" : v < 0 ? "#dc2626" : v < 8 ? "#d97706" : "#16a34a";
  const wasNow = (now, was, kind, inv) => {
    if (now == null || was == null) return `<div class="w" style="color:#94a3b8">—</div>`;
    const up = now >= was, good = inv ? !up : up;
    const wtxt = kind === "gun" ? Math.round(was) + " gün" : money(was);
    return `<div class="w" style="color:${good ? "#3ecf8e" : "#ff6b5a"}">${up ? "▲" : "▼"} YoY · gy ${wtxt}</div>`;
  };
  const list = (arr, kf, vf) => arr.map(x => `<div class="kok-row"><span class="rk">${esc(kf(x))}</span><span class="rv">${vf(x)}</span></div>`).join("");
  const zone = (clr, title, q) => `<div style="margin:17px 2px 9px"><div style="font-size:11px;font-weight:800;text-transform:uppercase;letter-spacing:.5px;color:${clr}">${title}</div>${q ? `<div style="font-size:11px;color:#94a3b8;font-weight:600;margin-top:2px">${q}</div>` : ""}</div>`;
  const coll = (id, title, sub, content) => `<div class="kok-sec" style="padding:0;overflow:hidden"><button class="kok-coll" data-t="${id}" style="width:100%;border:0;background:none;display:flex;align-items:center;justify-content:space-between;padding:12px 14px;font-family:inherit;cursor:pointer;text-align:left"><span style="font-size:13px;font-weight:700;color:#334155">${title}</span><span style="font-size:12px;color:#94a3b8;font-weight:600;white-space:nowrap">${sub} <span class="kchev" style="color:#cbd5e1;font-size:15px">›</span></span></button><div id="kc-${id}" style="display:none;padding:0 14px 12px">${content}</div></div>`;
  try {
    const d = await api("/api/bi/kokpit-data");
    let _dk = null; try { _dk = await api("/api/bi/mobil-dikkat"); } catch (e) { _dk = null; }
    let _ov = null; try { _ov = await api("/api/bi/odeme-vadeleri"); } catch (e) { _ov = null; }
    let _fi = null; try { _fi = await api("/api/bi/finansal-icgoru"); } catch (e) { _fi = null; }
    const v = d.vitals || {};
    let h = `<div class="kok-wrap">`;

    // ① AKSIYON — Dikkat
    if (_dk && ((_dk.kayip && _dk.kayip.length) || (_dk.buyuyen && _dk.buyuyen.length) || _dk.gecikme)) {
      const _sig = (clr, bg, html) => `<div style="display:flex;gap:8px;padding:7px 0;border-top:1px solid #f5eddc"><span style="width:8px;height:8px;border-radius:50%;background:${clr};box-shadow:0 0 0 3px ${bg};margin-top:5px;flex:0 0 auto"></span><div style="font-size:13px;line-height:1.42;color:#1f2937">${html}</div></div>`;
      let _dl = "";
      if (_dk.kayip && _dk.kayip.length) _dl += _sig("#ef4444", "#fee2e2", `<b>${_dk.kayip.length} müşteri alımını azalttı</b> — kayıp riski: <span style="color:#64748b">${esc(_dk.kayip.slice(0, 3).join(", "))}</span>. Ziyaret?`);
      if (_dk.gecikme) _dl += _sig("#f59e0b", "#fef3c7", `<b>Gecikmenin kaynağı:</b> <span style="color:#64748b">${esc(_dk.gecikme.ad)}</span> <b style="color:#b91c1c">${money(_dk.gecikme.net_m)} net</b>${_dk.gecikme.ilk5_pct != null ? ` — ilk 5 = %${_dk.gecikme.ilk5_pct}` : ""}. Bu hesabı kapat.`);
      if (_dk.buyuyen && _dk.buyuyen.length) _dl += _sig("#10b981", "#d1fae5", `<b>Büyüyenler:</b> <span style="color:#64748b">${esc(_dk.buyuyen.slice(0, 3).join(", "))}</span> — kış öncesi dokun.`);
      h += zone("#b45309", "⚡ Bugün ne yapmalı", "Karar: kimi ara, hangi hesabı kapat");
      h += `<div class="kok-sec" style="border-left:3px solid #f59e0b;background:linear-gradient(160deg,#fffdf7,#fff)">${_dl}</div>`;
    }

    // ② NABIZ — para + nakit (chip + #kok-p, _loadDonem doldurur)
    h += zone("#0f172a", "🩺 Nabız · para & nakit", "Karar: işler yolunda mı, nakit güvende mi");
    h += `<div class="kok-donem" style="display:flex;gap:6px;overflow-x:auto;margin-bottom:10px;padding-bottom:2px">
      ${["buay:Bu ay","sonay:Son ay","3ay:Son 3 ay","ytd:YTD"].map(function(x){var pp=x.split(":");return `<button class="kok-chip" data-p="${pp[0]}" style="flex:0 0 auto;border:1px solid #e2e8f0;background:#fff;color:#64748b;border-radius:20px;padding:6px 13px;font-size:12.5px;font-weight:700;white-space:nowrap;font-family:inherit">${pp[1]}</button>`;}).join("")}
    </div><div id="kok-p"></div>`;

    // ③ NAKIT — vade + gecikme kaynagi + simulasyon
    h += zone("#0284c7", "💧 Nakit · kimi sıkıştırayım", "Karar: tahsilat aksiyonu + finansman etkisi");
    if (_ov && _ov.musteri && _ov.tedarikci) {
      const mg = _ov.musteri.ort_gun, tg = _ov.tedarikci.ort_gun, fk = _ov.fark_gun;
      const farkTxt = fk > 0 ? `Müşteriler <b>${Math.abs(fk)} gün</b> daha geç ödüyor — aradaki farkı sen finanse ediyorsun.` : fk < 0 ? `Tedarikçiler seni <b>${Math.abs(fk)} gün</b> finanse ediyor — nakit lehine.` : `Vadeler dengeli.`;
      const farkRenk = fk > 0 ? "#dc2626" : fk < 0 ? "#16a34a" : "#64748b";
      const kv = _ov.kovalar || [];
      const bar = (arr, renk) => kv.map((k, i) => { const p = (arr[i] && arr[i].pct) || 0; return `<div style="display:flex;align-items:center;gap:6px;margin:2px 0"><div style="width:52px;font-size:11px;color:#64748b;text-align:right">${esc(k)}</div><div style="flex:1;background:#f1f5f9;border-radius:3px;height:14px;overflow:hidden"><div style="width:${Math.min(p,100)}%;background:${renk};height:100%;border-radius:3px"></div></div><div style="width:40px;font-size:11px;color:#0f172a;font-weight:600">${pct(p)}</div></div>`; }).join("");
      h += `<div class="kok-sec"><div class="kok-sb">💳 Vade · Müşteri vs Tedarikçi</div>
        <div style="display:flex;gap:8px;margin-bottom:8px">
          <div style="flex:1;background:#f0f9ff;border-radius:8px;padding:8px 10px"><div style="font-size:11px;color:#0284c7;font-weight:700">● MÜŞTERİ</div><div style="font-size:18px;font-weight:800;color:#0f172a">${Math.round(mg)} gün</div><div style="font-size:10px;color:#94a3b8">ort. tahsilat</div></div>
          <div style="flex:1;background:#fffbeb;border-radius:8px;padding:8px 10px"><div style="font-size:11px;color:#d97706;font-weight:700">● TEDARİKÇİ</div><div style="font-size:18px;font-weight:800;color:#0f172a">${Math.round(tg)} gün</div><div style="font-size:10px;color:#94a3b8">ort. ödeme</div></div>
        </div>
        <div style="font-size:12px;color:${farkRenk};line-height:1.5;margin-bottom:10px;padding:6px 8px;background:#f8fafc;border-radius:6px">${farkTxt}</div>
        <div style="font-size:11px;color:#0284c7;font-weight:700;margin:6px 0 2px">Müşteri tahsilat dağılımı</div>${bar(_ov.musteri.dagilim, "#0284c7")}
        <div style="font-size:11px;color:#d97706;font-weight:700;margin:8px 0 2px">Tedarikçi ödeme dağılımı</div>${bar(_ov.tedarikci.dagilim, "#f59e0b")}
      </div>`;
    }
    if (_fi && _fi.baglam) {
      const _mtl = (x) => (x == null || isNaN(x)) ? null : (Math.abs(x) >= 1e6 ? (x / 1e6).toLocaleString("tr-TR", { maximumFractionDigits: 1 }) + " M₺" : Math.round(x).toLocaleString("tr-TR") + " ₺");
      const bg = _fi.baglam;
      if (bg.koken && bg.koken.top && bg.koken.top.length) {
        const K = bg.koken;
        let kh = `<div class="kok-sec"><div class="kok-sb">🎯 Gecikme kaynağı · net <span style="color:#94a3b8;font-weight:700">ilk 5 = %${K.top5_pct != null ? K.top5_pct : "—"}</span></div>`;
        if (bg.etki && bg.etki.mahsup > 0) kh += `<div style="font-size:10.5px;color:#334155;margin-bottom:4px">Brüt <b>${_mtl(bg.etki.overdue_brut)}</b> → net <b style="color:#b91c1c">${_mtl(bg.etki.overdue)}</b> · KRB borcuyla <b>${_mtl(bg.etki.mahsup)}</b> mahsup</div>`;
        K.top.slice(0, 5).forEach(c => { kh += `<div class="kok-row"><span class="rk" style="max-width:60%">${esc(c.ad)}<span style="color:#94a3b8"> · ${esc(c.vade)}</span></span><span class="rv" style="color:#b91c1c;font-weight:700">${_mtl(c.overdue)}${c.pct != null ? ` <span style="color:#94a3b8;font-weight:400">%${c.pct}</span>` : ""}</span></div>`; });
        if (bg.simulasyon && bg.simulasyon.length) {
          bg.simulasyon.forEach(sm => { kh += `<div style="background:#f0fdf4;border-radius:8px;padding:8px 10px;margin-top:7px"><div style="font-size:12px;font-weight:800;color:#065f46">🧮 ${esc(sm.ad)}</div><div style="font-size:11.5px;color:#334155;margin-top:3px;line-height:1.55">Tahsilat: <b>${_mtl(sm.tahsil)}</b>${sm.yeni_dso != null ? ` · DSO: <b>${sm.yeni_dso}</b> gün` : ""} · yıllık tasarruf: <b style="color:#047857">${_mtl(sm.tasarruf_yil)}</b>${sm.brutkar_geri_pct != null ? ` · brüt kârın <b>%${sm.brutkar_geri_pct}</b>'i` : ""}</div></div>`; });
        }
        kh += `</div>`;
        h += kh;
      }
    }

    // ④ KIRILIM — analiz (katli)
    h += zone("#94a3b8", "🔎 Kırılım · analiz", "Dokun-aç · glance değil, kazmak için");
    if (d.marka?.length) h += coll("marka", "🏷 Marka", esc((d.marka[0] && d.marka[0].m) || "") + " · +" + Math.max(0, d.marka.length - 1), list(d.marka.slice(0, 12), x => x.m, x => `${money(x.c)} · <span style="color:${mjc(x.mj)}">${pct(x.mj)}</span>`));
    if (d.segment?.length) h += coll("segment", "🧩 Segment", esc((d.segment[0] && d.segment[0].s) || "") + " · " + d.segment.length, list(d.segment, x => x.s, x => `${money(x.c)} · <span style="color:${mjc(x.mj)}">${pct(x.mj)}</span>`));
    if (d.kanal?.length) h += coll("kanal", "📊 Satış kanalı", esc((d.kanal[0] && d.kanal[0].k) || ""), list(d.kanal, x => x.k, x => `${money(x.c)} · <span style="color:${mjc(x.mj)}">${pct(x.mj)}</span>`));
    if (d.sezon?.length) h += coll("sezon", "🍂 Sezon", esc((d.sezon[0] && d.sezon[0].s) || ""), list(d.sezon, x => x.s, x => `${money(x.c)} · <span style="color:${mjc(x.mj)}">${pct(x.mj)}</span>`));
    h += `<div class="kok-sec" style="display:flex;justify-content:space-between;align-items:center"><span style="font-size:13px;font-weight:700;color:#334155">📦 Stok değeri</span><span style="font-size:13px;font-weight:800">${money(v.stok)} <span style="font-size:11px;color:#94a3b8;font-weight:600">· şu an</span></span></div>`;
    if (d.piyasa && d.piyasa.izlenen?.length) h += coll("radar", "📡 Piyasa Radar", (d.piyasa.alarm || 0) + " alarm", d.piyasa.izlenen.slice(0, 8).map(z => `<div class="kok-row"><span class="rk">${esc(z.marka || "")} ${esc(z.ebat || "")}</span><span class="rv">${z.son_min != null ? Number(z.son_min).toLocaleString("tr-TR") + " ₺" : "—"}${z.alarm ? ` <span style="color:#dc2626">●${z.alarm}</span>` : ""}</span></div>`).join(""));
    if (d.insights?.length) { const ins = d.insights[0]; h += coll("icgoru", "💡 Marka-marj içgörü", "+" + d.insights.length, `<div style="font-size:13px;color:#0f172a;font-weight:600;margin-bottom:4px">${esc(ins.ozet || "")}</div><div style="font-size:12px;color:#475569;line-height:1.5">${esc((ins.anlati || "").slice(0, 260))}</div>${ins.oneri ? `<div style="font-size:12px;color:#6d28d9;margin-top:6px">→ ${esc(ins.oneri)}</div>` : ""}`); }

    h += `</div>`;
    m.innerHTML = h;

    // ---- toggle (donem) ----
    const _donemCfg = { buay: { q: "?ay=1", canli: true, lbl: "Bu ay" }, sonay: { q: "?ay=1", lbl: "Son ay" }, "3ay": { q: "?ay=3", lbl: "Son 3 ay" }, ytd: { q: "?ytd=1", lbl: "YTD" } };
    const _yc = (now, gy, unit) => {
      if (now == null || gy == null || gy == 0) return `<div class="w" style="color:#94a3b8">YoY —</div>`;
      const dp = unit === "p" ? (now - gy) : ((now - gy) / Math.abs(gy) * 100);
      const up = dp >= 0;
      const txt = unit === "p" ? `${up ? "▲" : "▼"}${Math.abs(dp).toFixed(1)}p` : `${up ? "▲" : "▼"}${Math.abs(Math.round(dp))}%`;
      const gyt = unit === "p" ? pct(gy) : money(gy);
      return `<div class="w" style="color:${up ? "#3ecf8e" : "#ff6b5a"}">${txt} YoY · gy ${gyt}</div>`;
    };
    async function _loadDonem(p) {
      const cfg = _donemCfg[p] || _donemCfg.sonay;
      const pel = document.getElementById("kok-p"); if (!pel) return;
      (m.querySelectorAll ? m.querySelectorAll(".kok-chip") : []).forEach(function (c) { const on = c.getAttribute("data-p") === p; c.style.background = on ? "#0f172a" : "#fff"; c.style.color = on ? "#fff" : "#64748b"; c.style.borderColor = on ? "#0f172a" : "#e2e8f0"; });
      pel.innerHTML = `<div style="padding:16px;color:#94a3b8;font-size:13px">Dönem yükleniyor…</div>`;
      let u = null; try { u = await api("/api/bi/kokpit-umbrella" + cfg.q); } catch (e) { u = null; }
      let ciro = null, marj = null, ciroGy = null, marjGy = null;
      if (cfg.canli && u && u.canli) { ciro = u.canli.ciro; marj = u.canli.marj; ciroGy = u.canli_gy ? u.canli_gy.ciro : null; marjGy = null; }
      else if (u && u.toplam) { ciro = u.toplam.ciro; marj = u.toplam.marj; ciroGy = u.yoy ? u.yoy.ciro : null; marjGy = u.yoy ? u.yoy.marj : null; }
      const gm = (_dk && _dk.gecikme) ? _dk.gecikme.toplam_m : null;
      const g5 = (_dk && _dk.gecikme && _dk.gecikme.ilk5_pct != null) ? _dk.gecikme.ilk5_pct : null;
      const cashV = (l, n, note, noteRed) => `<div class="kok-v" style="background:#fff;border:1px solid #fecaca"><div class="l" style="color:#b91c1c">${l}</div><div class="n" style="color:#b91c1c">${n}</div><div class="w" style="color:${noteRed ? "#dc2626" : "#94a3b8"}">${note}</div></div>`;
      let vg = `<div class="kok-vitals">
        <div class="kok-v"><div class="l">Ciro · ${esc(cfg.lbl)}</div><div class="n">${money(ciro)}</div>${_yc(ciro, ciroGy, "m")}</div>
        <div class="kok-v"><div class="l">Marj · ${esc(cfg.lbl)}</div><div class="n">${pct(marj)}</div>${_yc(marj, marjGy, "p")}</div>
        ${cashV("◆ DSO · şu an", (v.dso != null ? Math.round(v.dso) + " gün" : "—"), (v.dso_was != null ? "▲ gy " + Math.round(v.dso_was) : "—") + (v.dso != null && v.dso > 120 ? " · kritik" : ""), v.dso != null && v.dso > 120)}
        ${cashV("◆ Gecikmiş · net", (gm != null ? money(gm) : "—"), (g5 != null ? "ilk 5 = %" + g5 : "net açık"), true)}
      </div>`;
      let ii = "";
      if (u && u.tuketici && u.ticari) {
        const _tk = u.tuketici.ciro || 0, _tc = u.ticari.ciro || 0, _tot = _tk + _tc;
        if (_tot > 0) {
          const _tkp = Math.round(_tk / _tot * 100), _tcp = 100 - _tkp;
          ii = `<div class="kok-sec" style="padding:10px 14px"><div style="display:flex;justify-content:space-between;font-size:10.5px;font-weight:700;color:#94a3b8;margin-bottom:6px;text-transform:uppercase;letter-spacing:.3px"><span>⑂ İki İş · ciro payı</span><span>${esc(cfg.lbl)}</span></div><div style="display:flex;height:22px;border-radius:7px;overflow:hidden;background:#f1f5f9"><div style="width:${_tkp}%;min-width:44px;background:linear-gradient(180deg,#34d399,#10b981);color:#053528;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800">Tük %${_tkp}</div><div style="width:${_tcp}%;min-width:44px;background:linear-gradient(180deg,#60a5fa,#3b82f6);color:#06203f;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800">Tic %${_tcp}</div></div><div style="display:flex;justify-content:space-between;margin-top:7px;font-size:11px;color:#475569;font-weight:600"><span>Tüketici <span style="color:#94a3b8">marj ${pct(u.tuketici.marj)}</span></span><span>Ticari <span style="color:#94a3b8">marj ${pct(u.ticari.marj)}</span></span></div></div>`;
        }
      }
      pel.innerHTML = vg + ii;
    }
    (m.querySelectorAll ? m.querySelectorAll(".kok-chip") : []).forEach(function (c) { c.addEventListener("click", function () { _loadDonem(c.getAttribute("data-p")); }); });
    // ---- kirilim katla ----
    (m.querySelectorAll ? m.querySelectorAll(".kok-coll") : []).forEach(function (b) {
      b.addEventListener("click", function () {
        const t = b.getAttribute("data-t"); const box = document.getElementById("kc-" + t); if (!box) return;
        const open = box.style.display !== "none"; box.style.display = open ? "none" : "block";
        const ch = b.querySelector(".kchev"); if (ch) ch.style.transform = open ? "none" : "rotate(90deg)";
      });
    });
    _loadDonem("sonay");
  } catch (e) {
    m.innerHTML = `<div class="kok-wrap"><div class="kart kart-karar" style="margin:12px">Kokpit verisi gelmedi.<div style="font-size:12px;color:#94a3b8;margin-top:6px">${esc(e.message)}</div></div></div>`;
  }
}'''

s = s[:start] + NEW + s[span_end:] + "\n/* FAZD_OWNERLENS */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] FAZD_OWNERLENS — owner-lens duzen: Dikkat -> Nabiz(para+nakit) -> Nakit -> Kirilim(katli); AI-icgoru cikti")
