#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SEZON_UI_V1 — teshvik durumu ekranda GORUNSUN.
#   • Hangi sezon/arac tipi icin hesaplandi?
#   • Tam eslesme mi, genel kademeye mi dusuldu?
#   • Tesvik TANIMLI DEGILSE: marj gosterme, ACIKCA soyle.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep("""// AYKIRI_UI_V1 ────────────────────────────────────────────────────────""",
"""// SEZON_UI_V1 ─────────────────────────────────────────────────────────
// Ikame maliyeti = liste - tesvik. Hangi tesvik kademesi uygulandi?
// Tesvik yoksa marj UYDURMUYORUZ — "tanimli degil" diyoruz.
function _tesvikHTML(k) {
  const t = k.tesvik;
  if (!t) return "";
  const SEZ = { KIS: "Kış", YAZ: "Yaz", "4MEVSIM": "4 Mevsim", TUM: "Tüm sezon" };
  const ARC = { BINEK: "Binek", SUV: "SUV", HAFIF_TICARI: "Hafif Ticari",
                KAMYON: "Kamyon/TBR", OTOBUS: "Otobüs", IS_MAKINESI: "İş Makinesi", TUM: "Tüm araçlar" };
  const urun = (SEZ[t.sezon] || t.sezon || "—") + " · " + (ARC[t.arac_tipi] || t.arac_tipi || "—");

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
  }

  // Tam eslesme degilse, hangi kademeye dusuldugunu SOYLE.
  const kademeNot = {
    tam_eslesme: null,
    sezon_genel: "Bu sezona özel teşvik yok; aynı araç tipinin genel oranı kullanıldı.",
    arac_genel:  "Bu araç tipine özel teşvik yok; aynı sezonun genel oranı kullanıldı.",
    genel:       "Ne sezona ne araç tipine özel teşvik var; markanın genel oranı kullanıldı."
  }[t.kademe];

  const es = t.eslesen || {};
  const eslesenStr = (SEZ[es.sezon] || es.sezon || "?") + " · " + (ARC[es.arac_tipi] || es.arac_tipi || "?");
  const tam = t.kademe === "tam_eslesme";

  return `
    <div style="margin-top:5px;padding:5px 7px;background:${tam ? "#f0fdf4" : "#fffbeb"};border-radius:5px;border-left:3px solid ${tam ? "#16a34a" : "#f59e0b"}">
      <div style="font-size:11px;color:${tam ? "#15803d" : "#b45309"};font-weight:700">
        ${tam ? "✅" : "⚠"} Teşvik: ${esc(eslesenStr)}${k.iskonto_pct != null ? ` · <b>%${k.iskonto_pct}</b> indirim` : ""}
      </div>
      <div style="font-size:11px;color:#64748b;margin-top:2px">
        Ürün: ${esc(urun)}${kademeNot ? `<br><span style="color:#b45309">${esc(kademeNot)}</span>` : ""}
      </div>
    </div>`;
}

// AYKIRI_UI_V1 ────────────────────────────────────────────────────────""",
    "tesvik-html")

# Kalem satirina ekle — kendi satis ve vade bloklarindan ONCE (maliyet baglami)
rep("""        ${_kendiSatisHTML(k)}
        ${_vadeMaliyetHTML(k)}
      </div>`;""",
"""        ${_tesvikHTML(k)}
        ${_kendiSatisHTML(k)}
        ${_vadeMaliyetHTML(k)}
      </div>`;""",
    "tesvik-kalem")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
