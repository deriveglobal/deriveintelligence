# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ANALIZ_RENDER_V3b — swap the inventory-cost margin line for price-list margin
# (Liste / İndirim / Net maliyet / Marj %+₺/adet, with fiyat listesi/teşvik yok).
# Targeted edits against the deployed v2 renderer.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK: %s" % tag)

# 1) price-list margin helper, inserted before the renderer
HELPER = r'''function _marjHTML(k) {
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  if (k.fiyat_durumu === "liste_yok") return `<span style="color:#94a3b8;font-style:italic">Fiyat listesi yok — marj hesaplanamıyor</span>`;
  const marjColor = (k.marj_pct != null && k.marj_pct < 10) ? "#dc2626" : (k.marj_pct != null && k.marj_pct < 20) ? "#f59e0b" : "#16a34a";
  const karStr = k.kar_adet != null ? (` · Kâr: <b>₺${Number(k.kar_adet).toLocaleString("tr-TR")}/adet</b>`) : "";
  const iskStr = k.fiyat_durumu === "tesvik_yok" ? ` · <span style="color:#b45309">teşvik yok</span>` : (k.iskonto_pct != null ? ` · İndirim: <b>%${k.iskonto_pct}</b>` : "");
  return `Liste: <b>${tl(k.liste_fiyati)}</b>${iskStr} · Net maliyet: <b>${tl(k.net_maliyet)}</b> · Marj: <b style="color:${marjColor}">${k.marj_pct != null ? "%" + k.marj_pct : "—"}</b>${karStr}`;
}

function _teklifAnalizHTML(az) {'''
rep("function _teklifAnalizHTML(az) {", HELPER, "marj-helper")

# 2) replace the inventory-cost margin line with Stok/İstenen + price-list margin
rep('        <div style="margin-top:3px;color:#475569">Stok: <b style="color:${stokColor}">${stokStr}</b>${k.birim_maliyet != null ? ` · Maliyet: <b>${tl(k.birim_maliyet)}</b>` : ""}${k.talep_fiyat != null ? ` · İstenen: <b>${tl(k.talep_fiyat)}</b>` : ""} · Marj: <b style="color:${marjColor}">${marjStr}</b>${(k.talep_fiyat != null && k.birim_maliyet != null) ? ` · Kâr: <b>₺${Math.round(k.talep_fiyat - k.birim_maliyet).toLocaleString("tr-TR")}/adet</b>` : ""}</div>',
    '        <div style="margin-top:3px;color:#475569">Stok: <b style="color:${stokColor}">${stokStr}</b>${k.talep_fiyat != null ? ` · İstenen: <b>${tl(k.talep_fiyat)}</b>` : ""}</div>\n        <div style="margin-top:3px;color:#475569">${_marjHTML(k)}</div>',
    "margin-line")

# 3) header title
rep("📊 Karar Bilgisi — Stok & Rakip", "📊 Karar Bilgisi — Stok, Marj & Rakip", "title")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
