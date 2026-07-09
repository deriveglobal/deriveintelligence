#!/usr/bin/env python3
# ANALIZ_UI_V1 — approval modal: decision-context panel (stock/cost/margin +
# market ranges), rep-reported rival, and a real Notlar section (header +
# per-line), with honest "girilmemiş" empty states.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK: %s" % tag)

# 1) placeholder div, right above the Oluşturan/Tarih grid
rep('    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px 16px;font-size:13px;margin-bottom:14px">',
    '<div id="td-analiz-kutu" style="margin-bottom:12px"></div>\n    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px 16px;font-size:13px;margin-bottom:14px">',
    "placeholder")

# 2) fetch analiz after the log-history load
rep("  } catch (_) { /* log fetch failure is non-critical */ }",
    r"""  } catch (_) { /* log fetch failure is non-critical */ }

  // Load per-line stock + rival decision context
  try {
    const _az = await api(`/api/saha/teklifler/${t.id}/analiz`);
    const _ak = document.getElementById("td-analiz-kutu");
    if (_ak) _ak.innerHTML = _teklifAnalizHTML(_az);
  } catch (_) {}""",
    "fetch")

# 3) the renderer, inserted before satirDet
RENDERER = r"""function _teklifAnalizHTML(az) {
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
}

function satirDet(label, val) {"""
rep("function satirDet(label, val) {", RENDERER, "renderer")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
