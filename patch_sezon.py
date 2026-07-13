#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SEZON_V1 — ikame maliyeti artik SEZON ve ARAC TIPINI dikkate aliyor.
#
# BULUNAN HATA:
#   Sorgu:  WHERE marka=$2 AND rim araligi  ORDER BY rim_alt  LIMIT 1
#   Tabloda ayni marka+rim icin 2-3 satir var (BINEK / SUV / HAFIF_TICARI).
#   LIMIT 1 bunlardan RASTGELE birini aliyordu.
#   BRIDGESTONE/LASSA'da BINEK %35, SUV %39 -> yanlis secim = 4 puan hata.
#
#   Daha kotusu: tabloda SADECE sezon='KIS' var. YAZ tesviki YOK.
#   Ama sorgu sezona bakmadigi icin, bir YAZ lastigine KIS iskontosu
#   uyguluyordu. Bu yil satislarin 4.794'u YAZ, 945'i KIS.
#   Yani EN COK SATILAN kategoride ikame maliyeti (ve marj) YANLISTI.
#
#   Ayrica KAMYON/OTOBUS icin tabloda tek satir yok -> TBR (1.711 satir,
#   cironun en buyuk parcasi) tesviksiz ya da yanlis tesvikle hesaplaniyordu.
#
# COZUM:
#   • Lastigin KENDI kategorisinden sezon + arac_tipi turet.
#   • En OZELDEN en GENELE ara: (marka,tip,sezon) > (marka,tip,TUM)
#                                > (marka,TUM,sezon) > (marka,TUM,TUM)
#   • Hicbiri yoksa: "TESVIK TANIMLI DEGIL" de. YANLIS marj GOSTERME.
#   • Hangi kademenin eslestigini de dondur -- onaylayan neye baktigini bilsin.
#
# ⚠ TASARIM: kod veriyi BEKLEMEZ. KRB yaz/TBR tesvikini yukledigi AN,
#   hicbir kod degisikligi olmadan hesaplamaya baslar.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# 1) Yardimci: kalemden sezon + arac_tipi turet — SUTUN 0 (global)
rep("""async function _buildBrainPrompt(tenantId) {""",
"""// SEZON_V1 ──────────────────────────────────────────────────────────────
// Lastigin kendi kategorisinden tesvik anahtarlarini turet.
// bi_fiyat_iskonto CHECK:
//   sezon     : YAZ | KIS | 4MEVSIM | TUM
//   arac_tipi : BINEK | SUV | HAFIF_TICARI | OTOBUS | KAMYON | IS_MAKINESI | TUM
function _tesvikAnahtar(k) {
  const kat  = String(k.kategori || '').toUpperCase();
  const kat2 = String(k.kategori2 || '').toUpperCase();
  const grup = String(k.grup_adi || '').toUpperCase();
  const ebat = String(k.ebat || '').toUpperCase();

  // ── SEZON
  let sezon = 'TUM';
  if (kat.indexOf('4 MEVSIM') >= 0 || kat.indexOf('4MEVSIM') >= 0) sezon = '4MEVSIM';
  else if (kat.indexOf('KIS') >= 0 || kat.indexOf('KIŞ') >= 0)     sezon = 'KIS';
  else if (kat.indexOf('YAZ') >= 0)                                 sezon = 'YAZ';
  // TBR/LSR/OTR/IND ticari lastiktir; mevsim ayrimi yoktur -> TUM kalir.

  // ── ARAC TIPI
  let tip = 'BINEK';
  if (kat.indexOf('TBR') >= 0 || grup.indexOf('TICARI') >= 0)          tip = 'KAMYON';
  else if (kat.indexOf('OTR') >= 0 || kat.indexOf('IND') >= 0)          tip = 'IS_MAKINESI';
  else if (kat.indexOf('LSR') >= 0 || kat2.indexOf('MINIBUS') >= 0
           || kat2.indexOf('KAMYONET') >= 0 || /R\\d{2}C\\b/.test(ebat)) tip = 'HAFIF_TICARI';
  else if (kat2.indexOf('4X4') >= 0 || kat2.indexOf('SUV') >= 0)        tip = 'SUV';

  return { sezon: sezon, arac_tipi: tip };
}

// Tesvik kademesini EN OZELDEN EN GENELE ara.
// Bulamazsa null doner -> cagiran taraf "tesvik tanimli degil" der,
// UYDURMA bir oran KULLANMAZ.
async function _tesvikBul(pool, tenantId, marka, rim, sezon, tip) {
  const adaylar = [
    { sezon: sezon, tip: tip,   kademe: 'tam_eslesme' },
    { sezon: 'TUM', tip: tip,   kademe: 'sezon_genel' },
    { sezon: sezon, tip: 'TUM', kademe: 'arac_genel' },
    { sezon: 'TUM', tip: 'TUM', kademe: 'genel' }
  ];
  for (const a of adaylar) {
    const r = await pool.query(
      "SELECT baz_iskonto1 b1, baz_iskonto2 b2, ds, skala_primi sk, sezon, arac_tipi " +
      "  FROM bi_fiyat_iskonto " +
      " WHERE tenant_id=$1 AND upper(marka)=upper($2) AND aktif=true " +
      "   AND sezon=$3 AND arac_tipi=$4 " +
      "   AND (rim_alt IS NULL OR $5>=rim_alt) AND (rim_ust IS NULL OR $5<=rim_ust) " +
      " ORDER BY rim_alt NULLS LAST LIMIT 1",
      [tenantId, marka || '', a.sezon, a.tip, rim]);
    if (r.rows[0]) return Object.assign({}, r.rows[0], { kademe: a.kademe });
  }
  return null;
}

async function _buildBrainPrompt(tenantId) {""",
    "sezon-yardimci")


# 2) /analiz: eski LIMIT 1 sorgusunu degistir
rep("""            const _rm = String(k.ebat || "").match(/R\\s*(\\d{2})/i);
            const _rim = _rm ? parseInt(_rm[1]) : null;
            if (_rim != null) {
              const _isk = await pool.query("SELECT baz_iskonto1 b1, baz_iskonto2 b2, ds, skala_primi sk FROM bi_fiyat_iskonto WHERE tenant_id=$1 AND upper(marka)=upper($2) AND aktif=true AND (rim_alt IS NULL OR $3>=rim_alt) AND (rim_ust IS NULL OR $3<=rim_ust) ORDER BY rim_alt NULLS LAST LIMIT 1", [session.tenantId, k.marka || "", _rim]);
              if (_isk.rows[0]) {
                const _b1 = Number(_isk.rows[0].b1) || 0, _b2 = Number(_isk.rows[0].b2) || 0, _ds = Number(_isk.rows[0].ds) || 0, _sk = Number(_isk.rows[0].sk) || 0;
                const _nd = 1 - (1 - _b1 / 100) * (1 - _b2 / 100) * (1 - _ds / 100) * (1 - _sk / 100);
                if (_nd > 0) { _iskPct = Math.round(_nd * 1000) / 10; _fiyatDurumu = "ok"; }
              }
            }
            _netMaliyet = _iskPct != null ? Math.round(_liste * (1 - _iskPct / 100) * 100) / 100 : _liste;""",
"""            const _rm = String(k.ebat || "").match(/R\\s*(\\d{2})/i);
            const _rim = _rm ? parseInt(_rm[1]) : null;
            // SEZON_V1 — lastigin KENDI sezonu + arac tipiyle ara.
            //   Eskiden LIMIT 1 ile rastgele kademe seciliyordu; YAZ lastigine
            //   KIS iskontosu, SUV'a BINEK iskontosu uygulanabiliyordu.
            const _ta = _tesvikAnahtar(k);
            _tesvik_sezon = _ta.sezon; _tesvik_arac = _ta.arac_tipi;
            if (_rim != null) {
              const _isk = await _tesvikBul(pool, session.tenantId, k.marka, _rim, _ta.sezon, _ta.arac_tipi);
              if (_isk) {
                const _b1 = Number(_isk.b1) || 0, _b2 = Number(_isk.b2) || 0, _ds = Number(_isk.ds) || 0, _sk = Number(_isk.sk) || 0;
                const _nd = 1 - (1 - _b1 / 100) * (1 - _b2 / 100) * (1 - _ds / 100) * (1 - _sk / 100);
                if (_nd > 0) {
                  _iskPct = Math.round(_nd * 1000) / 10;
                  _fiyatDurumu = "ok";
                  _tesvik_kademe = _isk.kademe;
                  _tesvik_eslesen = { sezon: _isk.sezon, arac_tipi: _isk.arac_tipi };
                }
              } else {
                // ⚠ Bu urun icin tesvik TANIMLI DEGIL. Yanlis bir oran UYDURMUYORUZ.
                //   KRB yaz/TBR tesvik tablosunu yukledigi AN burasi kendiliginden
                //   hesaplamaya baslar -- kod degisikligi gerekmez.
                _fiyatDurumu = "tesvik_tanimsiz";
              }
            }
            // Tesvik yoksa ikame maliyeti HESAPLANMAZ (liste fiyatini maliyet
            // saymak marji oldugundan DUSUK gosterir -> yanlis red kararlari).
            _netMaliyet = _iskPct != null ? Math.round(_liste * (1 - _iskPct / 100) * 100) / 100 : null;""",
    "analiz-tesvik-sorgu")


# 3) Degiskenleri tanimla
rep("""        let _liste = null, _iskPct = null, _netMaliyet = null, _fiyatDurumu = "liste_yok";""",
"""        let _liste = null, _iskPct = null, _netMaliyet = null, _fiyatDurumu = "liste_yok";
        let _tesvik_sezon = null, _tesvik_arac = null, _tesvik_kademe = null, _tesvik_eslesen = null;""",
    "analiz-degiskenler")


# 4) Cikti: hangi kademenin eslestigini onaylayan gorsun
rep("""          kendi_satis: _kendi, agirlikli: _agir });""",
"""          kendi_satis: _kendi, agirlikli: _agir,
          // SEZON_V1 — seffaflik: hangi tesvik kademesi uygulandi?
          tesvik: {
            sezon: _tesvik_sezon, arac_tipi: _tesvik_arac,
            kademe: _tesvik_kademe,           // tam_eslesme | sezon_genel | arac_genel | genel
            eslesen: _tesvik_eslesen,         // tabloda GERCEKTEN bulunan satir
            tanimli: _fiyatDurumu !== "tesvik_tanimsiz"
          } });""",
    "analiz-tesvik-cikti")


# 5) ⚠ Kalem sorgusu kategori/grup cekmiyordu — tesvik anahtari turetilemez.
rep("""      const kl = await pool.query("SELECT kalem_sira, kalem_kodu, marka, model, ebat, adet, birim_fiyat, talep_fiyat, notlar FROM saha_teklif_kalem WHERE tenant_id=$1 AND teklif_id=$2 ORDER BY kalem_sira", [session.tenantId, _tid]);""",
"""      // SEZON_V1: kategori/sezon/jant_grubu da lazim — tesvik anahtari bunlardan turetiliyor.
      const kl = await pool.query("SELECT kalem_sira, kalem_kodu, marka, model, ebat, adet, birim_fiyat, talep_fiyat, notlar, kategori, sezon, jant_grubu, alt_grup FROM saha_teklif_kalem WHERE tenant_id=$1 AND teklif_id=$2 ORDER BY kalem_sira", [session.tenantId, _tid]);""",
    "kalem-kategori")

rep("""        const h = await pool.query("SELECT 1 AS kalem_sira, kalem_kodu, marka, model, ebat, adet, birim_fiyat, talep_fiyat, notlar FROM saha_teklif WHERE tenant_id=$1 AND id=$2", [session.tenantId, _tid]);""",
"""        const h = await pool.query("SELECT 1 AS kalem_sira, kalem_kodu, marka, model, ebat, adet, birim_fiyat, talep_fiyat, notlar, kategori, sezon, jant_grubu, alt_grup FROM saha_teklif WHERE tenant_id=$1 AND id=$2", [session.tenantId, _tid]);""",
    "teklif-kategori")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
