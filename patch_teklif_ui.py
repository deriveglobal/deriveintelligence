#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# TEKLIF_UI_V2 — onay ekraninda yeni karar bilgisi.
#
# ⚠ saha.js DERSI: gecmiste bir fonksiyonu KAPANIS (closure) icine yerlestirdim,
#   "Can't find variable: vRakip" hatasiyla TUM temsilci uygulamasi coktu.
#   Bu yuzden yeni fonksiyonlar SUTUN 0'da, mevcut _teklifAnalizHTML'in YANINA
#   ekleniyor. dispatch_guard.py bunu ayrica dogruluyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ── 1) YENI YARDIMCI FONKSIYONLAR — sutun 0, mevcut fonksiyonun ONUNE
rep("""function _teklifAnalizHTML(az) {""",
"""// TEKLIF_UI_V2 ────────────────────────────────────────────────────────
// Teklifin SATIS VADESI. Temsilci girmediyse musterinin ERP'deki son odeme
// kosulunu gosteriyoruz — ama VARSAYILAN oldugunu acikca yaziyoruz. Uydurmuyoruz.
function _vadeHTML(v) {
  if (!v) return "";
  const varsayilan = v.kaynak !== "teklif";
  const gunStr = v.gun != null ? (v.gun === 0 ? "Peşin" : v.gun + " gün") : (v.tur || "—");
  return `
    <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9;background:${varsayilan ? "#fffbeb" : "#f0fdf4"}">
      <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">💳 Satış vadesi</div>
      <div style="font-size:13px;font-weight:700;color:${varsayilan ? "#b45309" : "#15803d"}">${esc(gunStr)}${v.tur && v.gun != null ? ` <span style="font-weight:400;color:#64748b">(${esc(v.tur)})</span>` : ""}</div>
      ${varsayilan ? `<div style="font-size:11px;color:#b45309;margin-top:2px">⚠ Temsilci vade girmemiş — müşterinin son faturasındaki koşul gösteriliyor.</div>` : ""}
    </div>`;
}

// KENDI SATIS GECMISIMIZ (bu yil): min / medyan / max + KIM aldi.
// Fatih: "min fiyata tiklayinca kim aldigini gorsun" -> tiklamaya gerek yok,
// isim zaten yaninda. Ayni lastigi kime kaca satmisiz, ekranda.
function _kendiSatisHTML(k) {
  const ks = k.kendi_satis;
  if (!ks) return `<div style="margin-top:3px;color:#94a3b8;font-style:italic;font-size:11px">Bu ürünü bu yıl hiç satmamışız.</div>`;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const talep = k.talep_fiyat;
  // Talep, kendi medyanimizin NERESINDE? Karar icin en net sinyal bu.
  let konum = "";
  if (talep != null && ks.medyan != null) {
    const fark = Math.round((talep - ks.medyan) / ks.medyan * 100);
    const renk = fark < -15 ? "#dc2626" : fark < -5 ? "#f59e0b" : "#16a34a";
    const ok = fark < 0 ? "▼" : fark > 0 ? "▲" : "=";
    konum = `<span style="color:${renk};font-weight:700">${ok} medyandan %${Math.abs(fark)} ${fark < 0 ? "DÜŞÜK" : fark > 0 ? "yüksek" : ""}</span>`;
  }
  return `
    <div style="margin-top:5px;padding:5px 7px;background:#f8fafc;border-radius:5px;border-left:3px solid #6366f1">
      <div style="font-size:11px;color:#4338ca;font-weight:700;margin-bottom:2px">📗 Bu ürünü bu yıl kaça sattık (${ks.satis_adedi} satış)</div>
      <div style="font-size:12px;color:#0f172a">
        <b>${tl(ks.min)}</b> — <b>${tl(ks.medyan)}</b> — <b>${tl(ks.max)}</b> ${konum ? "· " + konum : ""}
      </div>
      <div style="font-size:11px;color:#64748b;margin-top:2px">
        En ucuz: <b>${esc(ks.en_ucuz.musteri || "—")}</b> (${tl(ks.en_ucuz.fiyat)})<br>
        En pahalı: <b>${esc(ks.en_pahali.musteri || "—")}</b> (${tl(ks.en_pahali.fiyat)})
      </div>
    </div>`;
}

// AGIRLIKLI VADELER + IKI MALIYET.
// ⚠ IKAME (liste-tesvik) = fiyatlama temeli: bu lastigi BUGUN yerine koyma bedeli.
//   BATIK (alis faturasi) = gecmiste odenen: gerceklesen marj raporu icin.
//   Ikisi ayrisiyorsa tedarikci zam yapmis demektir — onaylayan gormeli.
function _vadeMaliyetHTML(k) {
  const ag = k.agirlikli;
  if (!ag) return "";
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const gun = v => v != null ? Number(v) + " gün" : "—";
  const zam = ag.ikame_batik_fark_pct;
  const nakitUyari = (ag.alis_vade_gun != null && ag.satis_vade_gun != null && ag.satis_vade_gun > ag.alis_vade_gun)
    ? `<div style="font-size:11px;color:#dc2626;margin-top:2px">⚠ Tahsilat (${gun(ag.satis_vade_gun)}) ödemeden (${gun(ag.alis_vade_gun)}) UZUN — nakit akışı aleyhimize.</div>` : "";
  const zamUyari = (zam != null && zam > 5)
    ? `<div style="font-size:11px;color:#dc2626;margin-top:2px">⚠ İkame maliyeti geçmişte ödediğimizden <b>%${zam}</b> yüksek — tedarikçi zam yapmış. Eski ucuz maliyete göre indirim vermek YARINKİ marjı yer.</div>` : "";
  return `
    <div style="margin-top:5px;padding:5px 7px;background:#fefce8;border-radius:5px;border-left:3px solid #ca8a04">
      <div style="font-size:11px;color:#854d0e;font-weight:700;margin-bottom:2px">⏱ Vade & Maliyet (bu yıl, ağırlıklı)</div>
      <div style="font-size:11px;color:#0f172a">
        Alış: <b>${tl(ag.alis_fiyat)}</b> / <b>${gun(ag.alis_vade_gun)}</b> vade <span style="color:#94a3b8">(geçmişte ödenen)</span><br>
        Satış: ${ag.satis_fiyat != null ? `<b>${tl(ag.satis_fiyat)}</b> / ` : ""}<b>${gun(ag.satis_vade_gun)}</b> vade
      </div>
      ${nakitUyari}${zamUyari}
    </div>`;
}

function _teklifAnalizHTML(az) {""",
    "yeni-fonksiyonlar")


# ── 2) Kalem satirina yeni bloklari ekle
rep("""        ${hasRival
          ? `<div style="margin-top:3px;color:#475569">${et ? `Piyasa (e-ticaret): <b>${et}</b>${k.eticaret.ilan ? ` <span style="color:#94a3b8">(${k.eticaret.ilan} ilan)</span>` : ""}<br>` : ""}${ma ? `Marka aralığı: <b>${ma}</b><br>` : ""}${(sa && sa.adet) ? `Saha teklifleri: <b>${aralik(sa)}</b> <span style="color:#94a3b8">(ort ${tl(sa.ortalama)}, ${sa.adet} kayıt${sa.son_tarih ? `, son ${new Date(sa.son_tarih).toLocaleDateString("tr-TR")}` : ""})</span>` : ""}</div>`
          : `<div style="margin-top:3px;color:#94a3b8;font-style:italic">Piyasa/e-ticaret verisi yok.</div>`}
      </div>`;""",
"""        ${hasRival
          ? `<div style="margin-top:3px;color:#475569">${et ? `Piyasa (e-ticaret): <b>${et}</b>${k.eticaret.ilan ? ` <span style="color:#94a3b8">(${k.eticaret.ilan} ilan)</span>` : ""}<br>` : ""}${ma ? `Marka aralığı: <b>${ma}</b><br>` : ""}${(sa && sa.adet) ? `Saha teklifleri: <b>${aralik(sa)}</b> <span style="color:#94a3b8">(ort ${tl(sa.ortalama)}, ${sa.adet} kayıt${sa.son_tarih ? `, son ${new Date(sa.son_tarih).toLocaleDateString("tr-TR")}` : ""})</span>` : ""}</div>`
          : `<div style="margin-top:3px;color:#94a3b8;font-style:italic">Piyasa/e-ticaret verisi yok.</div>`}
        ${_kendiSatisHTML(k)}
        ${_vadeMaliyetHTML(k)}
      </div>`;""",
    "kalem-bloklari")


# ── 3) Baslikta teklifin VADESI + baslik metni
rep("""      <div style="background:#eef2ff;padding:8px 10px;font-weight:700;font-size:12px;color:#3730a3">📊 Karar Bilgisi — Stok, Marj & Rakip</div>
      <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9">""",
"""      <div style="background:#eef2ff;padding:8px 10px;font-weight:700;font-size:12px;color:#3730a3">📊 Karar Bilgisi — Vade, Kendi Satışımız, Maliyet & Rakip</div>
      ${_vadeHTML(az.vade)}
      <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9">""",
    "baslik-vade")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
