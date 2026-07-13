#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# AYKIRI_UI_V1 — "3 aykiri satis haric tutuldu (goster)" + tiklaninca liste.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# 1) Aykiri listesini acan global fonksiyon — SUTUN 0 (closure tuzagi!)
rep("""// TEKLIF_UI_V2 ────────────────────────────────────────────────────────""",
"""// AYKIRI_UI_V1 ────────────────────────────────────────────────────────
// Araliktan cikarilan satislari GOSTER. Gizlemiyoruz — tiklayinca aciliyor.
// Aykiri kayitlari kalem bazinda saklariz; DOM'a JSON gommekten kacinmak icin.
window._AYKIRI_KAYIT = window._AYKIRI_KAYIT || {};

function _aykiriGoster(anahtar) {
  const d = window._AYKIRI_KAYIT[anahtar];
  if (!d || !d.liste || !d.liste.length) return;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const tarih = t => t ? new Date(t).toLocaleDateString("tr-TR") : "—";
  const satirlar = d.liste.map(function (x) {
    return `
      <tr style="border-top:1px solid #f1f5f9">
        <td style="padding:6px 8px;font-size:12px"><b>${esc(x.musteri || "—")}</b></td>
        <td style="padding:6px 8px;font-size:12px;text-align:right;color:#dc2626;font-weight:700">${tl(x.fiyat)}</td>
        <td style="padding:6px 8px;font-size:12px;text-align:right">${x.adet != null ? x.adet : "—"}</td>
        <td style="padding:6px 8px;font-size:12px;color:#64748b">${tarih(x.tarih)}</td>
        <td style="padding:6px 8px;font-size:11px;color:#94a3b8">${esc(x.fatura_no || "—")}</td>
        <td style="padding:6px 8px;font-size:11px;color:#94a3b8">${esc(x.temsilci || "—")}</td>
      </tr>`;
  }).join("");
  modal(`
    <h3>⚠ Aralık dışında tutulan satışlar — ${esc(d.urun)}</h3>
    <div style="font-size:12px;color:#475569;margin-bottom:8px">
      Bu satışlar fiyat aralığı hesabına <b>dahil edilmedi</b>, çünkü birim fiyatları
      medyanın (<b>${tl(d.medyan)}</b>) %30'unun altında — yani <b>${tl(d.esik)}</b> altı.
      Genelde numune, garanti değişimi, iade düzeltmesi ya da giriş hatasıdır.
      <b>Silinmediler; sadece aralığı çarpıtmasınlar diye ayrıldılar.</b>
    </div>
    <div style="max-height:320px;overflow:auto;border:1px solid #e2e8f0;border-radius:6px">
      <table style="width:100%;border-collapse:collapse">
        <thead><tr style="background:#f8fafc">
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Müşteri</th>
          <th style="padding:6px 8px;text-align:right;font-size:11px;color:#64748b">Birim fiyat</th>
          <th style="padding:6px 8px;text-align:right;font-size:11px;color:#64748b">Adet</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Tarih</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Fatura</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Temsilci</th>
        </tr></thead>
        <tbody>${satirlar}</tbody>
      </table>
    </div>
    <div style="margin-top:8px;font-size:11px;color:#94a3b8">
      Bir tanesi gerçek bir satışsa, fiyat politikası açısından ayrıca incelenmeli.
    </div>
  `);
}

// TEKLIF_UI_V2 ────────────────────────────────────────────────────────""",
    "aykiri-modal")


# 2) _kendiSatisHTML: aykiri notu + tiklanabilir link
rep("""function _kendiSatisHTML(k) {
  const ks = k.kendi_satis;
  if (!ks) return `<div style="margin-top:3px;color:#94a3b8;font-style:italic;font-size:11px">Bu ürünü bu yıl hiç satmamışız.</div>`;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const talep = k.talep_fiyat;""",
"""function _kendiSatisHTML(k) {
  const ks = k.kendi_satis;
  if (!ks) return `<div style="margin-top:3px;color:#94a3b8;font-style:italic;font-size:11px">Bu ürünü bu yıl hiç satmamışız.</div>`;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const talep = k.talep_fiyat;

  // AYKIRI_UI_V1 — araliktan cikarilanlari GORUNUR yap (tiklanabilir).
  let aykiriHTML = "";
  if (ks.aykiri_sayisi > 0) {
    const anahtar = "ay_" + (k.kalem_sira || 0) + "_" + String(k.ebat || "").replace(/\\W/g, "");
    window._AYKIRI_KAYIT[anahtar] = {
      urun: (k.marka || "") + " " + (k.ebat || ""),
      medyan: ks.medyan, esik: ks.aykiri_esigi, liste: ks.aykirilar || []
    };
    aykiriHTML = `
      <div style="margin-top:3px;font-size:11px;color:#b45309">
        ⚠ <b>${ks.aykiri_sayisi}</b> aykırı satış aralık dışında tutuldu
        <span style="color:#94a3b8">(medyanın %30'u = ${tl(ks.aykiri_esigi)} altı)</span>
        · <a href="#" onclick="event.preventDefault();_aykiriGoster('${anahtar}')"
             style="color:#2563eb;text-decoration:underline;font-weight:600">göster</a>
      </div>`;
  }""",
    "aykiri-not")

rep("""      <div style="font-size:11px;color:#64748b;margin-top:2px">
        En ucuz: <b>${esc(ks.en_ucuz.musteri || "—")}</b> (${tl(ks.en_ucuz.fiyat)})<br>
        En pahalı: <b>${esc(ks.en_pahali.musteri || "—")}</b> (${tl(ks.en_pahali.fiyat)})
      </div>
    </div>`;""",
"""      <div style="font-size:11px;color:#64748b;margin-top:2px">
        En ucuz: <b>${esc(ks.en_ucuz.musteri || "—")}</b> (${tl(ks.en_ucuz.fiyat)})<br>
        En pahalı: <b>${esc(ks.en_pahali.musteri || "—")}</b> (${tl(ks.en_pahali.fiyat)})
      </div>
      ${aykiriHTML}
    </div>`;""",
    "aykiri-goster")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
