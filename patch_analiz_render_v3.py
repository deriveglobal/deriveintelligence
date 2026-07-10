# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ANALIZ_RENDER_V3 — final approval panel renderer: price-list margin
# (Liste / İndirim / Net / Marj %+₺/adet with "fiyat listesi yok / teşvik yok"),
# reworded market empty-state, per-line rep rival. Replaces _teklifAnalizHTML.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = r'''function _teklifAnalizHTML(az) {
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const aralik = r => (r && r.en_dusuk != null) ? (tl(r.en_dusuk) + " – " + tl(r.en_yuksek)) : null;
  const lineNotes = (az.kalemler || []).filter(k => k.notlar)
    .map(k => `<div style="font-size:12px;color:#334155;margin-top:2px">• <b>${esc(k.marka || "")} ${esc(k.ebat || "")}</b>: ${esc(k.notlar)}</div>`).join("");
  const notlarHTML = (az.notlar || lineNotes)
    ? `${az.notlar ? `<div style="font-size:12px;color:#0f172a">${esc(az.notlar)}</div>` : ""}${lineNotes}`
    : `<div style="font-size:12px;color:#94a3b8;font-style:italic">Not girilmemiş.</div>`;
  const rr = az.rep_rakip || [];
  const headerR = az.header_rakip;
  let repRakipHTML;
  if (rr.length || headerR) {
    const items = [];
    if (headerR) items.push((headerR.marka || "Rakip") + (headerR.fiyat != null ? (" · " + tl(headerR.fiyat)) : ""));
    rr.forEach(x => items.push((x.marka || "Rakip") + (x.ebat ? (" " + x.ebat) : "") + (x.fiyat != null ? (" · " + tl(x.fiyat)) : "") + (x.supheli ? " ⚠ şüpheli olabilir" : "")));
    repRakipHTML = `<div style="font-size:12px;color:#0f172a">${items.map(esc).join("<br>")}</div>`;
  } else {
    repRakipHTML = `<div style="font-size:12px;color:#94a3b8;font-style:italic">Rakip bilgisi girilmemiş.</div>`;
  }
  const lineHTML = (az.kalemler || []).map(k => {
    const stokStr = k.mevcut_stok != null ? (k.mevcut_stok + " adet") : "—";
    const stokColor = (k.mevcut_stok != null && k.mevcut_stok <= 0) ? "#dc2626" : "#0f172a";
    const marjStr = k.marj_pct != null ? ("%" + k.marj_pct) : "—";
    const marjColor = (k.marj_pct != null && k.marj_pct < 10) ? "#dc2626" : (k.marj_pct != null && k.marj_pct < 20) ? "#f59e0b" : "#16a34a";
    const et = aralik(k.eticaret);
    const ma = aralik(k.marka_araligi);
    const sa = k.saha_teklifler;
    const hasRival = et || ma || (sa && sa.adet);
    return `
      <div style="border-top:1px solid #f1f5f9;padding:8px 10px;font-size:12px">
        <b style="color:#0f172a">${esc(k.marka || "")} ${esc(k.ebat || "")}</b>
        <div style="margin-top:3px;color:#475569">Stok: <b style="color:${stokColor}">${stokStr}</b>${k.birim_maliyet != null ? ` · Maliyet: <b>${tl(k.birim_maliyet)}</b>` : ""}${k.talep_fiyat != null ? ` · İstenen: <b>${tl(k.talep_fiyat)}</b>` : ""} · Marj: <b style="color:${marjColor}">${marjStr}</b></div>
        ${hasRival
          ? `<div style="margin-top:3px;color:#475569">${et ? `Piyasa (e-ticaret): <b>${et}</b>${k.eticaret.ilan ? ` <span style="color:#94a3b8">(${k.eticaret.ilan} ilan)</span>` : ""}<br>` : ""}${ma ? `Marka aralığı: <b>${ma}</b><br>` : ""}${(sa && sa.adet) ? `Saha teklifleri: <b>${aralik(sa)}</b> <span style="color:#94a3b8">(ort ${tl(sa.ortalama)}, ${sa.adet} kayıt${sa.son_tarih ? `, son ${new Date(sa.son_tarih).toLocaleDateString("tr-TR")}` : ""})</span>` : ""}</div>`
          : `<div style="margin-top:3px;color:#94a3b8;font-style:italic">Rakip bilgisi girilmemiş.</div>`}
      </div>`;
  }).join("");
  return `
    <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden">
      <div style="background:#eef2ff;padding:8px 10px;font-weight:700;font-size:12px;color:#3730a3">📊 Karar Bilgisi — Stok & Rakip</div>
      <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9">
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">🏁 Temsilcinin belirttiği rakip</div>
        ${repRakipHTML}
      </div>
      ${lineHTML}
      <div style="padding:8px 10px;border-top:1px solid #f1f5f9;background:#fafafa">
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">📝 Notlar</div>
        ${notlarHTML}
      </div>
    </div>`;
}'''

NEW = r'''function _teklifAnalizHTML(az) {
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const aralik = r => (r && r.en_dusuk != null) ? (tl(r.en_dusuk) + " – " + tl(r.en_yuksek)) : null;
  const rr = az.rep_rakip || [];
  const _nz = e => String(e || "").toLowerCase().replace(/\s/g, "");
  const _rrEbat = eb => rr.filter(x => x.ebat && _nz(x.ebat) === _nz(eb));
  const _rrTop = rr.filter(x => !x.ebat || !(az.kalemler || []).some(k => _nz(k.ebat) === _nz(x.ebat)));
  const _rivalStr = x => (x.marka || "Rakip") + (x.ebat ? (" " + x.ebat) : "") + (x.fiyat != null ? (" · " + tl(x.fiyat)) : " · fiyat yok") + (x.supheli ? " ⚠ şüpheli" : "");
  const lineNotes = (az.kalemler || []).filter(k => k.notlar)
    .map(k => `<div style="font-size:12px;color:#334155;margin-top:2px">• <b>${esc(k.marka || "")} ${esc(k.ebat || "")}</b>: ${esc(k.notlar)}</div>`).join("");
  const notlarHTML = (az.notlar || lineNotes)
    ? `${az.notlar ? `<div style="font-size:12px;color:#0f172a">${esc(az.notlar)}</div>` : ""}${lineNotes}`
    : `<div style="font-size:12px;color:#94a3b8;font-style:italic">Not girilmemiş.</div>`;
  let repRakipHTML;
  if (_rrTop.length || az.header_rakip) {
    const items = [];
    if (az.header_rakip) items.push((az.header_rakip.marka || "Rakip") + (az.header_rakip.fiyat != null ? (" · " + tl(az.header_rakip.fiyat)) : ""));
    _rrTop.forEach(x => items.push(_rivalStr(x)));
    repRakipHTML = `<div style="font-size:12px;color:#0f172a">${items.map(esc).join("<br>")}</div>`;
  } else {
    repRakipHTML = `<div style="font-size:12px;color:#94a3b8;font-style:italic">Rakip bilgisi girilmemiş.</div>`;
  }
  const lineHTML = (az.kalemler || []).map(k => {
    const stokStr = k.mevcut_stok != null ? (k.mevcut_stok + " adet") : "—";
    const stokColor = (k.mevcut_stok != null && k.mevcut_stok <= 0) ? "#dc2626" : "#0f172a";
    let marjHTML;
    if (k.fiyat_durumu === "liste_yok") {
      marjHTML = `<span style="color:#94a3b8;font-style:italic">Fiyat listesi yok — marj hesaplanamıyor</span>`;
    } else {
      const marjColor = (k.marj_pct != null && k.marj_pct < 10) ? "#dc2626" : (k.marj_pct != null && k.marj_pct < 20) ? "#f59e0b" : "#16a34a";
      const karStr = k.kar_adet != null ? (` · Kâr: <b>₺${Number(k.kar_adet).toLocaleString("tr-TR")}/adet</b>`) : "";
      const iskStr = k.fiyat_durumu === "tesvik_yok" ? ` · <span style="color:#b45309">teşvik yok</span>` : (k.iskonto_pct != null ? ` · İndirim: <b>%${k.iskonto_pct}</b>` : "");
      marjHTML = `Liste: <b>${tl(k.liste_fiyati)}</b>${iskStr} · Net maliyet: <b>${tl(k.net_maliyet)}</b> · Marj: <b style="color:${marjColor}">${k.marj_pct != null ? "%" + k.marj_pct : "—"}</b>${karStr}`;
    }
    const et = aralik(k.eticaret);
    const ma = aralik(k.marka_araligi);
    const sa = k.saha_teklifler;
    const hasMarket = et || ma || (sa && sa.adet);
    return `
      <div style="border-top:1px solid #f1f5f9;padding:8px 10px;font-size:12px">
        <b style="color:#0f172a">${esc(k.marka || "")} ${esc(k.ebat || "")}</b>
        <div style="margin-top:3px;color:#475569">Stok: <b style="color:${stokColor}">${stokStr}</b>${k.talep_fiyat != null ? ` · İstenen: <b>${tl(k.talep_fiyat)}</b>` : ""}</div>
        <div style="margin-top:3px;color:#475569">${marjHTML}</div>
        ${_rrEbat(k.ebat).length ? `<div style="margin-top:3px;color:#b45309;font-weight:600">🏁 Temsilci: ${_rrEbat(k.ebat).map(_rivalStr).map(esc).join(" · ")}</div>` : ""}
        ${hasMarket
          ? `<div style="margin-top:3px;color:#475569">${et ? `Piyasa (e-ticaret): <b>${et}</b>${k.eticaret.ilan ? ` <span style="color:#94a3b8">(${k.eticaret.ilan} ilan)</span>` : ""}<br>` : ""}${ma ? `Marka aralığı: <b>${ma}</b><br>` : ""}${(sa && sa.adet) ? `Saha teklifleri: <b>${aralik(sa)}</b> <span style="color:#94a3b8">(ort ${tl(sa.ortalama)}, ${sa.adet} kayıt)</span>` : ""}</div>`
          : `<div style="margin-top:3px;color:#94a3b8;font-style:italic">Piyasa/e-ticaret verisi yok.</div>`}
      </div>`;
  }).join("");
  return `
    <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden">
      <div style="background:#eef2ff;padding:8px 10px;font-weight:700;font-size:12px;color:#3730a3">📊 Karar Bilgisi — Stok, Marj & Rakip</div>
      <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9">
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">🏁 Temsilcinin belirttiği rakip</div>
        ${repRakipHTML}
      </div>
      ${lineHTML}
      <div style="padding:8px 10px;border-top:1px solid #f1f5f9;background:#fafafa">
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">📝 Notlar</div>
        ${notlarHTML}
      </div>
    </div>`;
}'''

c = s.count(OLD)
assert c == 1, "ABORT: _teklifAnalizHTML anchor found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: renderer-v3")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
