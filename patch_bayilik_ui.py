#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# BAYILIK_UI_V1 — ekran IKI TEDARIK MODELINI ayirsin.
#   🅑 BAYILIK  -> "Teşvik: Kış · Binek · %35 indirim"   (liste - tesvik)
#   🅝 NET ALIM -> "Net alım · son alış 12.400 TL (18 gün önce, PETLAS A.Ş.)"
#                  Tesvik ARAMAZ, "tanimli degil" DEMEZ.
#   Bayilik markasinda tesvik satiri YOKSA -> gercek boşluk, ACIKCA soyle.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep("""  const urun = (SEZ[t.sezon] || t.sezon || "—") + " · " + (ARC[t.arac_tipi] || t.arac_tipi || "—");

  if (!t.tanimli) {
    return `
      <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
        <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Bu ürün için teşvik tanımlı değil</div>
        <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
          Aranan: <b>${esc(urun)}</b> · ${esc(k.marka || "")}<br>
          Teşvik oranı bilinmediği için <b>ikame maliyeti ve marj hesaplanamıyor</b>.
          Yanlış bir oran uydurmuyoruz — karar verirken kendi satış aralığımıza ve
          gerçekleşen alış maliyetine bakın.
        </div>
      </div>`;
  }""",
"""  const urun = (SEZ[t.sezon] || t.sezon || "—") + " · " + (ARC[t.arac_tipi] || t.arac_tipi || "—");

  // ── BAYILIK_UI_V1: NET ALIM markasi (KRB bayisi degil) ────────────────
  //   Tesvik yok cunku tesvik KAVRAMI yok. Ikame maliyeti = son net alis.
  if (t.tedarik === "net_alim") {
    const n = t.net_alim;
    if (!n) {
      return `
        <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
          <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Bu ürünü hiç almamışız</div>
          <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
            ${esc(k.marka || "")} bayilik markamız değil — net alım yapılır, teşvik yoktur.
            Ama bu kalemin <b>hiç alış faturası yok</b>, dolayısıyla ikame maliyeti bilinmiyor.
            Fiyat vermeden önce alış maliyetini teyit edin.
          </div>
        </div>`;
    }
    const tar = String(n.tarih || "").slice(0, 10).split("-").reverse().join(".");
    return `
      <div style="margin-top:5px;padding:5px 7px;background:${n.bayat ? "#fffbeb" : "#f0fdf4"};border-radius:5px;border-left:3px solid ${n.bayat ? "#f59e0b" : "#16a34a"}">
        <div style="font-size:11px;color:${n.bayat ? "#b45309" : "#15803d"};font-weight:700">
          ${n.bayat ? "⚠" : "✅"} Net alım · son alış <b>₺${Number(n.fiyat).toLocaleString("tr-TR")}</b>
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:2px">
          ${esc(tar)} · ${n.gun_once} gün önce${n.tedarikci ? " · " + esc(n.tedarikci) : ""}${n.vade_gun != null ? " · " + n.vade_gun + " gün vade" : ""}<br>
          ${esc(k.marka || "")} bayilik markamız değil; net fiyata alınır, teşvik uygulanmaz.
          <b>İkame maliyeti = bu fiyat.</b>
          ${n.bayat ? `<br><span style="color:#b45309">Bu fiyat ${n.gun_once} günlük — güncel olmayabilir, marja temkinli bakın.</span>` : ""}
        </div>
      </div>`;
  }

  // ── BAYILIK markasi ama tesvik satiri YOK -> GERCEK BOSLUK ────────────
  if (!t.tanimli) {
    return `
      <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
        <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Teşvik tablosu eksik — ${esc(k.marka || "")}</div>
        <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
          ${esc(k.marka || "")} bayilik markamız, yani <b>teşvik olması gerekiyor</b> —
          ama <b>${esc(urun)}</b> için sisteme yüklenmemiş.<br>
          Teşvik oranı bilinmediği için <b>ikame maliyeti ve marj hesaplanamıyor</b>.
          Yanlış bir oran uydurmuyoruz. Eksik teşvik tablosunu yükleyin;
          hesaplama kendiliğinden başlar.
        </div>
      </div>`;
  }""",
    "bayilik-net-alim")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
