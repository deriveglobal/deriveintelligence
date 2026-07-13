#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# BAYILIK_V2 — IKAME MALIYETI KADEME SIRASI. Ekran susmayi birakiyor.
#
# BAYILIK_V1 SONRASI OLCULEN DURUM (bu yil, lastik cirosu):
#   ⚠ %60,2 (248,0M) — BAYILIK markasi ama tesvik EKSIK  -> "hesaplanamiyor"
#   ✅ %38,2 (157,4M) — NET ALIM, son alis fiyati         -> hesaplaniyor
#   ✅ %1,2  (  5,0M) — BAYILIK, kis tesviki var          -> hesaplaniyor
#   ❌ %0,4  (  1,8M) — hic alinmamis                     -> bilinmiyor
#
#   Yani Pazartesi 8 temsilcinin teklif satirlarinin %60'inda MARJ GORUNMEYECEK.
#   Kabul edilemez. Ve GEREK DE YOK.
#
# ANAHTAR FIKIR:
#   ⚠ BAYILIK markasinda ALIS FATURASINDAKI fiyat TESVIKLERI ZATEN ICINDE TASIR.
#     Brisa'ya odedigin net fiyat = liste - tesvikler. Yani tesvik tablosu
#     eksikken bile ikame maliyetini BILIYORUZ: son alis faturasi.
#     Tek dezavantaji: biraz BAYAT olabilir. Bunu da SOYLUYORUZ.
#
# KADEME SIRASI (ikame_kaynak):
#   1) 'liste_tesvik' — bayilik + tesvik satiri VAR -> liste x (1-tesvik). EN GUNCEL.
#   2) 'son_alis'     — bayilik + tesvik YOK        -> son alis faturasi.
#                       Tesvik fiyatin ICINDE. "Tablo eksik, son alis kullanildi" der.
#   3) 'son_alis'     — net alim markasi            -> son alis faturasi. DOGRU TEMEL.
#   4) 'yok'          — hic alinmamis               -> BILINMIYOR. Uydurmuyoruz.
#
# ⚠ UYDURMUYORUZ. Sadece HANGI TEMELE baktigimizi soyluyoruz.
#   Tesvik yuklemek artik BIR ENGEL DEGIL, bir DOGRULUK IYILESTIRMESI.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# 1) Kademe mantigi — BAYILIK_V1 blogunu genislet
rep("""        // ── BAYILIK_V1: hangi tedarik modeli? ────────────────────────────
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
        } catch (e) { console.error("[bayilik_v1] analiz:", e && e.message); }""",
"""        // ── BAYILIK_V2: ikame maliyeti KADEME SIRASI ─────────────────────
        let _tedarik = null, _sonAlis = null, _ikameKaynak = "yok";
        try {
          _tedarik = (await _bayilikMi(pool, session.tenantId, k.marka)) ? "bayilik" : "net_alim";

          if (_tedarik === "bayilik" && _iskPct != null && _netMaliyet != null) {
            // KADEME 1 — tesvik satiri VAR. liste x (1-tesvik). EN GUNCEL TEMEL.
            _ikameKaynak = "liste_tesvik";
          } else {
            // KADEME 2/3 — SON ALIS FATURASI.
            //   Net alim markasinda: dogru temel, tesvik kavrami zaten yok.
            //   Bayilik markasinda : tesvik tablosu eksik AMA alis faturasindaki
            //     fiyat tesvikleri ZATEN ICINDE TASIYOR (Brisa'ya odenen net fiyat
            //     = liste - tesvik). Yani maliyeti BILIYORUZ; sadece biraz bayat.
            //     Bunu ekranda ACIKCA soyluyoruz -- gizlemiyoruz.
            if (_tedarik === "net_alim") { _iskPct = null; _tesvik_kademe = null; _tesvik_eslesen = null; }
            _sonAlis = await _sonAlisFiyati(pool, session.tenantId, k.kalem_kodu);
            if (_sonAlis) {
              _netMaliyet = _sonAlis.fiyat;
              _ikameKaynak = "son_alis";
              _fiyatDurumu = (_tedarik === "bayilik") ? "bayilik_son_alis" : "net_alim";
            } else {
              // KADEME 4 — bu kalemi HIC ALMAMISIZ. Maliyet BILINMIYOR.
              //   Liste fiyatini maliyet saymak marji oldugundan DUSUK gosterir
              //   -> yanlis red kararlari. UYDURMUYORUZ.
              _netMaliyet = null;
              _ikameKaynak = "yok";
              _fiyatDurumu = "alis_yok";
            }
          }
        } catch (e) { console.error("[bayilik_v2] analiz:", e && e.message); }""",
    "ikame-kademe")


# 2) Cikti: onaylayan HANGI TEMELE bakildigini gorsun
rep("""            // BAYILIK_V1
            tedarik: _tedarik,                // 'bayilik' | 'net_alim'
            net_alim: _sonAlis                // son alis: fiyat/tarih/tedarikci/gun_once/bayat
          } });""",
"""            // BAYILIK_V1 / V2
            tedarik: _tedarik,                // 'bayilik' | 'net_alim'
            ikame_kaynak: _ikameKaynak,       // 'liste_tesvik' | 'son_alis' | 'yok'
            net_alim: _sonAlis                // son alis: fiyat/tarih/tedarikci/gun_once/bayat
          } });""",
    "ikame-kaynak-cikti")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
