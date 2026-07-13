#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# BAYILIK_UI_V2 — ekran HANGI TEMELE baktigini soylesin.
#   liste_tesvik -> yesil  "Teşvik: Kış · Binek · %35 indirim"
#   son_alis     -> sari   "Teşvik tablosu eksik — son alış fiyatı kullanıldı"
#                          (bayilik markasinda tesvik ZATEN bu fiyatin icinde)
#   yok          -> kirmizi "Bu kalemi hiç almamışız — maliyet bilinmiyor"
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# 1) BAYILIK markasi + tesvik EKSIK + son alis VAR -> sari kutu, marj HESAPLANIR
rep("""  // ── BAYILIK markasi ama tesvik satiri YOK -> GERCEK BOSLUK ────────────
  if (!t.tanimli) {""",
"""  // ── BAYILIK_UI_V2: bayilik markasi, tesvik tablosu EKSIK, ama son alis VAR
  //   ⚠ Alis faturasindaki fiyat TESVIKLERI ZATEN ICINDE TASIR (Brisa'ya odenen
  //     net fiyat = liste - tesvik). Yani maliyet BILINIYOR; sadece biraz bayat.
  //     Marji gosteriyoruz AMA hangi temele bakildigini SOYLUYORUZ.
  if (t.tedarik === "bayilik" && t.ikame_kaynak === "son_alis" && t.net_alim) {
    const n = t.net_alim;
    const tar = String(n.tarih || "").slice(0, 10).split("-").reverse().join(".");
    return `
      <div style="margin-top:5px;padding:5px 7px;background:#fffbeb;border-radius:5px;border-left:3px solid #f59e0b">
        <div style="font-size:11px;color:#b45309;font-weight:700">
          ⚠ Teşvik tablosu eksik — son alış fiyatı kullanıldı: <b>₺${Number(n.fiyat).toLocaleString("tr-TR")}</b>
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:2px">
          ${esc(k.marka || "")} · <b>${esc(urun)}</b> teşviki sisteme yüklenmemiş.<br>
          Alış faturasındaki fiyat <b>teşvikleri zaten içinde taşır</b> (bayiye kesilen
          net fiyat = liste − teşvik), o yüzden maliyeti biliyoruz. Kaynak:
          ${esc(tar)} · ${n.gun_once} gün önce${n.tedarikci ? " · " + esc(n.tedarikci) : ""}.
          ${n.bayat ? `<br><span style="color:#b45309">Bu fiyat ${n.gun_once} günlük — zam gelmişse marj olduğundan yüksek görünür.</span>` : ""}
          <br>Teşvik tablosu yüklenirse hesap otomatik olarak liste−teşvike geçer.
        </div>
      </div>`;
  }

  // ── Maliyet HIC BILINMIYOR -> marj gosterme, sebebini soyle ───────────
  if (t.ikame_kaynak === "yok" || !t.tanimli) {""",
    "bayilik-fallback")


# 2) Kirmizi kutunun metni: artik sebep "tesvik eksik" degil, "hic almamisiz"
rep("""      <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
        <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Teşvik tablosu eksik — ${esc(k.marka || "")}</div>
        <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
          ${esc(k.marka || "")} bayilik markamız, yani <b>teşvik olması gerekiyor</b> —
          ama <b>${esc(urun)}</b> için sisteme yüklenmemiş.<br>
          Teşvik oranı bilinmediği için <b>ikame maliyeti ve marj hesaplanamıyor</b>.
          Yanlış bir oran uydurmuyoruz. Eksik teşvik tablosunu yükleyin;
          hesaplama kendiliğinden başlar.
        </div>
      </div>`;""",
"""      <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
        <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Maliyet bilinmiyor — ${esc(k.marka || "")}</div>
        <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
          <b>${esc(urun)}</b> için ne teşvik tanımlı, ne de bu kalemin <b>alış faturası</b> var
          — yani bu ürünü hiç almamışız.<br>
          İkame maliyeti bilinmediği için <b>marj hesaplanamıyor</b>. Yanlış bir oran
          uydurmuyoruz; liste fiyatını maliyet saymak marjı olduğundan düşük gösterirdi.
          Fiyat vermeden önce alış maliyetini teyit edin.
        </div>
      </div>`;""",
    "maliyet-bilinmiyor")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
