#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# KDV_V1 — IKI SESSIZ HATA. IKISI DE MARJI BOZUYOR.
#
# ═══ HATA 1: KDV BAYRAGI OKUNMUYOR ═══
#   bi_fiyat_listesi_uploads.kdv_haric diye bir kolon VAR ve DOGRU doldurulmus:
#     BRISA  (BRIDGESTONE/LASSA/DAYTON, 2026-06-05) -> kdv_haric = FALSE (KDV DAHIL)
#     CONTI  (CONTINENTAL/BARUM/MATADOR, 2026-05-01) -> kdv_haric = TRUE  (KDV HARIC)
#
#   KANIT: BRIDGESTONE 205/55R16 = 8.974 TL. Brisa'nin perakende listesindeki
#          (KDV DAHIL) rakamin BIREBIR AYNISI. Yani o satirlar KDV dahil.
#
#   AMA teklif ekraninin sorgusu u tablosuna JOIN yapip u.kdv_haric'i HIC OKUMUYOR.
#   -> BRISA'da liste %20 SISIK saniliyor
#   -> ikame maliyeti %20 YUKSEK
#   -> marj ~20 PUAN DUSUK gorunuyor
#   -> GM iyi teklifleri REDDEDIYOR
#
#   ornek LASSA 205/55R16:
#     ekran : 8.974 x (1-0,35) = 5.833 TL  ❌
#     dogru : 8.974/1,20 = 7.478 -> x(1-0,35) = 4.861 TL  ✅
#
#   ⚠ CONTI'de dogru hesapliyor. Yani AYNI EKRANDA iki marka grubu
#     FARKLI TEMELDE. Kimse fark etmemis cunku ikisi de "makul" gorunuyor.
#
# ═══ HATA 2: MARKA SIZMASI ═══
#   Sorgunun WHERE'inde MARKA FILTRESI YOK. Sadece ebat esleşiyor.
#   ORDER BY markayi TERCIH ediyor ama ZORUNLU tutmuyor:
#       ORDER BY (upper(u.marka)=upper($3)) DESC, u.liste_tarihi DESC LIMIT 1
#   -> LASSA teklifinde LASSA listesinde o ebat YOKSA,
#      sorgu CONTINENTAL'in liste fiyatini alip LASSA'nin maliyetini ondan hesapliyor.
#   -> Farkli marka, farkli fiyat seviyesi, ayni marj kutusu. SESSIZCE.
#
#   COZUM: marka esleşmesi ZORUNLU. Eslesmezse liste YOK de, BASKA MARKANIN
#          fiyatini KULLANMA. (BAYILIK_V2 zaten "liste yoksa son alis" diyor.)
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


rep("""          const _pl = await pool.query("SELECT k2.liste_fiyati FROM bi_fiyat_listesi_kalemler k2 JOIN bi_fiyat_listesi_uploads u ON u.id=k2.upload_id WHERE k2.tenant_id=$1 AND u.aktif=true AND k2.liste_fiyati IS NOT NULL AND regexp_replace(upper(k2.ebat),'\\\\s+','','g')=regexp_replace(upper($2),'\\\\s+','','g') ORDER BY (upper(u.marka)=upper($3)) DESC, u.liste_tarihi DESC LIMIT 1", [session.tenantId, k.ebat || "", k.marka || ""]);
          if (_pl.rows[0] && _pl.rows[0].liste_fiyati != null) {
            _liste = Number(_pl.rows[0].liste_fiyati);
            _fiyatDurumu = "tesvik_yok";""",
"""          // KDV_V1 — IKI DUZELTME:
          //   1) u.kdv_haric OKUNUYOR. false ise liste KDV DAHIL -> /1,20.
          //      Brisa listeleri KDV DAHIL (kanit: BRIDGESTONE 205/55R16 = 8.974,
          //      perakende listesindeki rakamin birebir aynisi). Conti KDV haric.
          //      Okumadan once ayni ekranda IKI MARKA GRUBU FARKLI TEMELDEYDI.
          //   2) MARKA ESLESMESI ZORUNLU. Eskiden WHERE'de marka filtresi YOKTU;
          //      ORDER BY sadece TERCIH ediyordu. LASSA'da ebat bulunamayinca
          //      CONTINENTAL'in liste fiyati aliniyordu. SESSIZCE.
          //      Artik eslesmezse liste YOK deriz — BASKA MARKANIN fiyatini KULLANMAYIZ.
          const _pl = await pool.query(
            "SELECT k2.liste_fiyati, u.kdv_haric, u.marka AS liste_marka " +
            "  FROM bi_fiyat_listesi_kalemler k2 " +
            "  JOIN bi_fiyat_listesi_uploads u ON u.id = k2.upload_id " +
            " WHERE k2.tenant_id = $1 AND u.aktif = true AND k2.liste_fiyati IS NOT NULL " +
            "   AND regexp_replace(upper(k2.ebat),'\\\\s+','','g') = regexp_replace(upper($2),'\\\\s+','','g') " +
            "   AND upper(u.marka) = upper($3) " +      // ⚠ ZORUNLU — sizma YOK
            " ORDER BY u.liste_tarihi DESC LIMIT 1",
            [session.tenantId, k.ebat || "", k.marka || ""]);
          if (_pl.rows[0] && _pl.rows[0].liste_fiyati != null) {
            const _ham = Number(_pl.rows[0].liste_fiyati);
            const _kdvHaric = _pl.rows[0].kdv_haric === true;
            // ⚠ kdv_haric=false -> liste KDV DAHIL -> KDV'yi CIKAR.
            //   Cikarmazsak maliyet %20 siser, marj 20 puan dusuk gorunur.
            _liste = _kdvHaric ? _ham : Math.round(_ham / 1.20 * 100) / 100;
            _liste_kdv_haric_mi = _kdvHaric;
            _liste_ham = _ham;
            _fiyatDurumu = "tesvik_yok";""",
    "kdv-liste-sorgu")


rep("""        let _tesvik_sezon = null, _tesvik_arac = null, _tesvik_kademe = null, _tesvik_eslesen = null;""",
"""        let _tesvik_sezon = null, _tesvik_arac = null, _tesvik_kademe = null, _tesvik_eslesen = null;
        // KDV_V1 — seffaflik: liste hangi bazda geldi, KDV cikarildi mi?
        let _liste_kdv_haric_mi = null, _liste_ham = null;""",
    "kdv-degiskenler")


rep("""            tanimli: _fiyatDurumu !== "tesvik_tanimsiz",
            // BAYILIK_V1 / V2
            tedarik: _tedarik,                // 'bayilik' | 'net_alim'
            ikame_kaynak: _ikameKaynak,       // 'liste_tesvik' | 'son_alis' | 'yok'
            net_alim: _sonAlis                // son alis: fiyat/tarih/tedarikci/gun_once/bayat
          } });""",
"""            tanimli: _fiyatDurumu !== "tesvik_tanimsiz",
            // BAYILIK_V1 / V2
            tedarik: _tedarik,                // 'bayilik' | 'net_alim'
            ikame_kaynak: _ikameKaynak,       // 'liste_tesvik' | 'son_alis' | 'yok'
            net_alim: _sonAlis,               // son alis: fiyat/tarih/tedarikci/gun_once/bayat
            // KDV_V1 — liste hangi bazda geldi? KDV cikarildi mi?
            liste: _liste_ham == null ? null : {
              ham: _liste_ham,
              kdv_haric_mi: _liste_kdv_haric_mi,
              kullanilan: _liste,
              not: _liste_kdv_haric_mi
                ? "Liste KDV hariç kaydedilmiş; aynen kullanıldı."
                : "Liste KDV DAHİL kaydedilmiş; maliyet için KDV çıkarıldı (÷1,20)."
            }
          } });""",
    "kdv-cikti")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
