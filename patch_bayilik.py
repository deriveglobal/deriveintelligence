#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# BAYILIK_V1 — IKI TEDARIK MODELI VAR. Kod tek modeli biliyordu.
#
# FATIH'IN DUZELTMESI:
#   KRB sadece BRISA (BRIDGESTONE/LASSA/DAYTON) ve CONTINENTAL
#   (CONTINENTAL/BARUM/MATADOR) BAYISI.
#
#   🅑 BAYILIK MARKASI  -> liste fiyati VAR, tesvik/iskonto VAR.
#                          ikame maliyeti = liste x (1 - tesvik)
#                          Bu yil cironun %61,3'u.
#
#   🅝 NET ALIM MARKASI -> tedarikciden NET fiyata alinir.
#                          Liste fiyati YOK, tesvik KAVRAMI YOK.
#                          ikame maliyeti = EN SON odenen net alis fiyati.
#                          Bu yil cironun %38,7'si (KUMHO 51M, SAILUN 32M...)
#
# BENIM HATAM (SEZON_V1):
#   Net alim markalarina "tesvik tanimli degil, marj hesaplanamiyor" diyordum.
#   YANLIS. Eksik veri degil -- o markada tesvik diye bir sey YOK.
#   Ikame maliyeti ZATEN elimizde: son alis faturasi.
#   Olculdu: net alim urunlerinin %98,9'unda alis faturasi VAR.
#   Yani 38,7% cironun marjini HESAPLAYABILIYORDUK, kod BAKMIYORDU.
#
# GERCEK BOSLUK (kucuk ve net):
#   Bayilik markalarinda tesvik tablosunda SADECE sezon=KIS ve
#   arac_tipi = BINEK/SUV/HAFIF_TICARI var. YAZ / 4MEVSIM / TBR YOK.
#   Bunlar gercekten eksik -- ekran bunu ACIKCA soyleyecek.
#
# ⚠ BAYILIK TESPITI VERIDEN: markanin bi_fiyat_iskonto'da AKTIF satiri var mi?
#   KRB ucuncu bir bayilik alirsa tabloyu doldurur, KOD DEGISMEDEN devreye girer.
#
# ⚠ bi_tedarikci_faturalari'nda 'ebat' KOLONU YOK (olculdu: jant_capi +
#   kalem_tanimi var). Eslestirme kalem_kodu uzerinden -- %98,9 kapsiyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ─────────────────────────────────────────────────────────────────────
# 1) Yardimcilar — SUTUN 0 (global). SEZON_V1 yardimcilarinin hemen ustune.
# ─────────────────────────────────────────────────────────────────────
rep("""// SEZON_V1 ──────────────────────────────────────────────────────────────""",
"""// BAYILIK_V1 ────────────────────────────────────────────────────────────
// Marka BAYILIK markasi mi, NET ALIM markasi mi?
//   Tespit VERIDEN: bi_fiyat_iskonto'da aktif satiri var mi?
//   Yeni bayilik alinirsa tablo dolar -> burasi kendiliginden 'bayilik' der.
async function _bayilikMi(pool, tenantId, marka) {
  if (!marka) return false;
  const r = await pool.query(
    "SELECT 1 FROM bi_fiyat_iskonto WHERE tenant_id=$1::uuid " +
    " AND upper(marka)=upper($2) AND aktif=true LIMIT 1",
    [tenantId, marka]);
  return r.rows.length > 0;
}

// NET ALIM markasinda IKAME MALIYETI = EN SON odedigimiz net fiyat.
//   ⚠ AGIRLIKLI ORTALAMA DEGIL. "Yerine koymak kaca mal olur" sorusunun
//     cevabi "bugun kaca alirim"dir; "gecmiste ortalama kaca aldim" DEGIL.
//     Agirlikli ortalama zaten ayrica gosteriliyor (batik maliyet).
//   ⚠ bi_tedarikci_faturalari'nda ebat kolonu YOK -> kalem_kodu ile eslestir.
//   ⚠ Fiyat bayatsa (>180 gun) SOYLE -- sessizce eski fiyatla marj hesaplama.
async function _sonAlisFiyati(pool, tenantId, kalemKodu) {
  if (!kalemKodu) return null;
  const r = await pool.query(
    "SELECT birim_fiyat_kdv_haric AS f, fatura_tarihi AS t, tedarikci_adi AS td, " +
    "       vade_gun AS vg, (CURRENT_DATE - fatura_tarihi)::int AS gun " +
    "  FROM bi_tedarikci_faturalari " +
    " WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric > 0 " +
    " ORDER BY fatura_tarihi DESC LIMIT 1",
    [tenantId, kalemKodu]);
  const x = r.rows[0];
  if (!x) return null;
  const g = Number(x.gun);
  return {
    fiyat: Math.round(Number(x.f) * 100) / 100,
    tarih: x.t, tedarikci: x.td,
    vade_gun: x.vg == null ? null : Number(x.vg),
    gun_once: g,
    bayat: g > 180
  };
}

// SEZON_V1 ──────────────────────────────────────────────────────────────""",
    "bayilik-yardimci")


# ─────────────────────────────────────────────────────────────────────
# 2) /analiz — marj hesaplanmadan HEMEN ONCE tedarik modelini belirle.
#    ⚠ Buraya koyuyoruz cunku yukaridaki tesvik blogu 'liste fiyati
#      bulunduysa' kosuluna bagli. Net alim markasinda liste YOK ->
#      o blok HIC calismiyor -> _netMaliyet null kaliyordu.
# ─────────────────────────────────────────────────────────────────────
rep("""        const marj = (talep && _netMaliyet) ? Math.round((talep - _netMaliyet) / talep * 1000) / 10 : null;
        const _karAdet = (talep != null && _netMaliyet != null) ? Math.round(talep - _netMaliyet) : null;""",
"""        // ── BAYILIK_V1: hangi tedarik modeli? ────────────────────────────
        let _tedarik = null, _sonAlis = null;
        try {
          _tedarik = (await _bayilikMi(pool, session.tenantId, k.marka)) ? "bayilik" : "net_alim";
          if (_tedarik === "net_alim") {
            // Tesvik ARAMIYORUZ -- bu markada tesvik KAVRAMI yok.
            _iskPct = null; _tesvik_kademe = null; _tesvik_eslesen = null;
            _sonAlis = await _sonAlisFiyati(pool, session.tenantId, k.kalem_kodu);
            if (_sonAlis) {
              _netMaliyet = _sonAlis.fiyat;          // IKAME = son net alis
              _fiyatDurumu = "net_alim";
            } else {
              _netMaliyet = null;
              _fiyatDurumu = "alis_yok";             // bu urunu HIC almamisiz
            }
          }
          // bayilik ise: _netMaliyet yukarida liste x (1-tesvik) ile hesaplandi.
          // Tesvik satiri yoksa null kalir -> ekran "eksik tesvik" der. DOGRU.
        } catch (e) { console.error("[bayilik_v1] analiz:", e && e.message); }

        const marj = (talep && _netMaliyet) ? Math.round((talep - _netMaliyet) / talep * 1000) / 10 : null;
        const _karAdet = (talep != null && _netMaliyet != null) ? Math.round(talep - _netMaliyet) : null;""",
    "analiz-tedarik-modeli")


# ─────────────────────────────────────────────────────────────────────
# 3) Cikti — onaylayan HANGI temele baktigini gorsun
# ─────────────────────────────────────────────────────────────────────
rep("""          tesvik: {
            sezon: _tesvik_sezon, arac_tipi: _tesvik_arac,
            kademe: _tesvik_kademe,           // tam_eslesme | sezon_genel | arac_genel | genel
            eslesen: _tesvik_eslesen,         // tabloda GERCEKTEN bulunan satir
            tanimli: _fiyatDurumu !== "tesvik_tanimsiz"
          } });""",
"""          tesvik: {
            sezon: _tesvik_sezon, arac_tipi: _tesvik_arac,
            kademe: _tesvik_kademe,           // tam_eslesme | sezon_genel | arac_genel | genel
            eslesen: _tesvik_eslesen,         // tabloda GERCEKTEN bulunan satir
            tanimli: _fiyatDurumu !== "tesvik_tanimsiz",
            // BAYILIK_V1
            tedarik: _tedarik,                // 'bayilik' | 'net_alim'
            net_alim: _sonAlis                // son alis: fiyat/tarih/tedarikci/gun_once/bayat
          } });""",
    "analiz-tedarik-cikti")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
