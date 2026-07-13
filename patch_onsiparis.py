#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ONSIPARIS_V1 — /api/bi/sezon/onsiparis
#
# ⚠ ESKI /api/bi/orders/preorder BOZUK: bi_stok_durumu (12 HAZIRAN'DA DONMUS),
#   grup_adi filtresi YOK, miktar>0 YOK. Yerine BU gelecek.
#
# ═══ TALEP TAHMINI NEYE DAYANIYOR — ve NEYE DAYANMIYOR ═══
#
# ❌ MARKA GECMISINE DAYANMIYOR. Cunku:
#      KRB 3 yil BRISA BAYISI DEGILDI (Nisan 2026'da dondu).
#      LASSA 2024'te 899 adet sattı — bayi degildi, satamiyordu.
#      O sayiyi taban alsam SIFIRA YAKIN siparis onerirdim. FELAKET.
#
# ✅ KATEGORI TOPLAMINA DAYANIYOR. Cunku:
#      Musteride kis lastigi ihtiyaci VAR. Hangi markadan aldigi
#      KRB'nin bayilik yapisina bagli. Toplam talep MARKADAN BAGIMSIZ.
#
#   OLCULEN KIS SEZONLARI (Eki-Oca, adet):
#     2021-22  38.020   (Brisa bayisi — Brisa payi 30.460)
#     2022-23  40.807   (Brisa bayisi — Brisa payi 34.794)
#     2023-24  29.253   (bayilik bitti — Brisa 428)
#     2024-25  19.163   (bayisiz — SAILUN 10.676 ikame)
#     2025-26  18.674   (bayisiz — SAILUN 10.850)
#   -> Brisa'yi kaybetmek kis hacminin YARISINDAN FAZLASINI goturdu.
#   -> Simdi Brisa dondu. Nis-Tem 2026'da Brisa hacmi 26.261 adet/3,5 ay
#      = 2021-22 bayili donemin USTUNDE hiz. Talep GERI GELIYOR.
#
# ⚠ SENARYO KULLANICININ KARARI, BENIM DEGIL.
#   "Brisa donusunun ne kadari geri gelir" bir IS KARARIDIR.
#   Uc senaryonun adet ve TL karsiligini gosteriyorum; SECIMI Fatih Bilen yapar.
#     temkinli 25.000 · baz 32.000 · iyimser 40.000
#
# ═══ FINANSMAN ESIGI: %7,1 ═══
#   Brisa taksit takvimi (KRB'nin kendi slaydi):
#     Tem/Agu/Eyl faturalanan -> 18 Kas 2026 + 16 Ara 2026
#     Eki/Kas/Ara faturalanan -> 22 Oca 2027 + 22 Sub 2027
#   ⚠ Odeme tarihleri TAKVIME CAKILI. Temmuz'da mal alsan bile
#     Kasim'a kadar PARA CIKMIYOR — stogu TEDARIKCI finanse ediyor.
#   Tek fark: 65 GUN daha erken odeme. %40/yil -> %7,1
#   KARAR: kesin_siparis_pct > 7,1 -> ERKEN AL. Altinda -> BEKLE.
#   ⚠ AMA: stok tukenme riski varsa prim ne olursa olsun ERKEN AL.
#
# ⚠ bi_tedarikci_tesvik.kesin_siparis_pct = 0.00 (TUM MARKALARDA — BOS).
#   Doldurulmadan model "erken/bekle" diyemez. Ekranda ACIKCA yaziyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

YENI = '''
// ONSIPARIS_V1 ═══════════════════════════════════════════════════════════
// GET /api/bi/sezon/onsiparis?sezon=KIS&senaryo=baz
//   senaryo: temkinli(25000) | baz(32000) | iyimser(40000) | <sayi>
if (request.method === "GET" && url.pathname === "/api/bi/sezon/onsiparis") {
  try {
    const session = await requireModuleAccess(request, "intelligence");
    if (!session.tenantId) { sendJson(response, 200, {}); return; }

    const sezon = (url.searchParams.get("sezon") || "KIS").toUpperCase();
    const sen   = (url.searchParams.get("senaryo") || "baz").toLowerCase();
    const SENARYO = { temkinli: 25000, baz: 32000, iyimser: 40000 };
    const hedefToplam = SENARYO[sen] || parseInt(sen) || SENARYO.baz;

    // ── Sezon penceresi
    const bugun = new Date();
    const ay = bugun.getMonth() + 1;
    const pencere = (sezon === "KIS")
      ? { aylar: [6, 7], ad: "Haziran–Temmuz", hedef_sezon: "Ekim–Ocak" }
      : { aylar: [11, 12], ad: "Kasım–Aralık", hedef_sezon: "Mart–Haziran" };
    const acik = pencere.aylar.indexOf(ay) >= 0;
    const kapanis = new Date(bugun.getFullYear(), pencere.aylar[pencere.aylar.length - 1], 0);
    const gunKaldi = Math.max(0, Math.round((kapanis - bugun) / 86400000));

    const KAT = sezon === "KIS" ? "%KIS%" : (sezon === "YAZ" ? "%YAZ%" : "%4 MEVSIM%");

    // ── EBAT bazinda KATEGORI talebi (TUM markalar) + mevcut stok
    //    ⚠ marka gecmisine DEGIL, kategori toplamina bakiyoruz. Sebep yukarida.
    const r = await query(`
      WITH son_maliyet AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
          FROM bi_tedarikci_faturalari
         WHERE tenant_id = $1::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
         ORDER BY kalem_kodu, fatura_tarihi DESC
      ),
      -- BAYILI DONEM (2021-22 + 2022-23): talebin GERCEK potansiyeli
      bayili AS (
        SELECT ebat, SUM(miktar) / 2.0 AS sezon_ort
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND grup_adi LIKE 'LASTIK%' AND miktar > 0
           AND kategori ILIKE $2 AND ebat <> ''
           AND ((fatura_tarihi >= DATE '2021-10-01' AND fatura_tarihi < DATE '2022-02-01')
             OR (fatura_tarihi >= DATE '2022-10-01' AND fatura_tarihi < DATE '2023-02-01'))
         GROUP BY 1
      ),
      -- SON SEZON: guncel musteri profili
      guncel AS (
        SELECT ebat, SUM(miktar) AS sezon_adet
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND grup_adi LIKE 'LASTIK%' AND miktar > 0
           AND kategori ILIKE $2 AND ebat <> ''
           AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
         GROUP BY 1
      ),
      -- HARMAN: bayili donem %60 (potansiyel) + son sezon %40 (guncel profil)
      --   ⚠ Bu bir AGIRLIKLANDIRMA KARARIDIR, veri degil. Ekranda yaziyor.
      harman AS (
        SELECT COALESCE(b.ebat, g.ebat) AS ebat,
               COALESCE(b.sezon_ort, 0) * 0.6 + COALESCE(g.sezon_adet, 0) * 0.4 AS agirlik
          FROM bayili b FULL JOIN guncel g ON g.ebat = b.ebat
      ),
      pay AS (
        SELECT ebat, agirlik, agirlik / NULLIF(SUM(agirlik) OVER (), 0) AS oran
          FROM harman WHERE agirlik > 0
      ),
      stok AS (
        SELECT s.ebat_norm AS ebat, SUM(s.adet) AS mevcut,
               SUM(s.adet * m.maliyet) / NULLIF(SUM(s.adet), 0) AS birim_maliyet
          FROM (
            SELECT COALESCE(NULLIF(regexp_replace(kalem_tanimi, '^([0-9]+[/.][0-9]*[A-Z]*R?[0-9.]+C?).*$', '\\\\1'), kalem_tanimi), '') AS ebat_norm,
                   kalem_kodu, adet
              FROM bi_stok_anlik
             WHERE tenant_id = $1::uuid AND adet > 0 AND sezon ILIKE $2
               AND export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
          ) s JOIN son_maliyet m ON m.kalem_kodu = s.kalem_kodu
         GROUP BY 1
      )
      SELECT p.ebat,
             ROUND(p.oran * 100, 2)                     AS talep_pay_pct,
             ROUND($3 * p.oran)                         AS hedef_adet,
             COALESCE(ROUND(st.mevcut), 0)              AS mevcut_stok,
             GREATEST(ROUND($3 * p.oran) - COALESCE(st.mevcut, 0), 0) AS eksik_adet,
             ROUND(COALESCE(st.birim_maliyet, 0))       AS birim_maliyet,
             ROUND(GREATEST(ROUND($3 * p.oran) - COALESCE(st.mevcut, 0), 0)
                   * COALESCE(st.birim_maliyet, 0))     AS tutar
        FROM pay p LEFT JOIN stok st ON st.ebat = p.ebat
       WHERE p.oran > 0.001
       ORDER BY p.oran DESC
       LIMIT 60`,
      [session.tenantId, KAT, hedefToplam]);

    const kalem = r.rows.map(x => ({
      ebat: x.ebat,
      talep_pay_pct: Number(x.talep_pay_pct),
      hedef: Number(x.hedef_adet),
      mevcut: Number(x.mevcut_stok),
      eksik: Number(x.eksik_adet),
      birim_maliyet: Number(x.birim_maliyet),
      tutar: Number(x.tutar),
      durum: Number(x.mevcut_stok) === 0 ? "yok"
           : Number(x.mevcut_stok) < Number(x.hedef_adet) * 0.3 ? "kritik"
           : Number(x.mevcut_stok) < Number(x.hedef_adet) * 0.7 ? "eksik" : "yeterli"
    }));

    // ── Tesvik: kesin siparis primi tanimli mi?
    const t = await query(`
      SELECT marka, kesin_siparis_pct, max_toplam_pct, odeme_vadesi_gun, fatura_kuru
        FROM bi_tedarikci_tesvik
       WHERE tenant_id = $1::uuid AND yil = EXTRACT(YEAR FROM CURRENT_DATE)::int
       ORDER BY marka`, [session.tenantId]);
    const tesvikVar = t.rows.some(x => Number(x.kesin_siparis_pct) > 0);

    const toplamEksik = kalem.reduce((a, k) => a + k.eksik, 0);
    const toplamTutar = kalem.reduce((a, k) => a + k.tutar, 0);
    const toplamMevcut = kalem.reduce((a, k) => a + k.mevcut, 0);

    sendJson(response, 200, {
      sezon: sezon,
      pencere: { acik: acik, ad: pencere.ad, hedef_sezon: pencere.hedef_sezon, gun_kaldi: gunKaldi },
      senaryo: { secilen: sen, hedef_toplam: hedefToplam,
        secenekler: [
          { ad: "temkinli", adet: 25000, aciklama: "Brisa kısmi geri dönüş. Toplam kış 19K→25K." },
          { ad: "baz",      adet: 32000, aciklama: "2021-22 bayili dönemin %80'i. Nis-Tem hızı bunu destekliyor." },
          { ad: "iyimser",  adet: 40000, aciklama: "2022-23 seviyesine tam dönüş (40.807)." }
        ],
        // ⚠ SENARYO SECIMI BIR IS KARARIDIR — model dayatmaz.
        uyari: "Senaryo seçimi Fatih Bilen'in kararıdır. Model üç seçeneğin adet ve TL karşılığını gösterir; birini dayatmaz."
      },
      ozet: {
        hedef_toplam: hedefToplam,
        mevcut_stok: toplamMevcut,
        eksik_adet: toplamEksik,
        tahmini_tutar: toplamTutar,
        karsilama_pct: Math.round(100 * toplamMevcut / Math.max(hedefToplam, 1))
      },
      esik: {
        finansman_maliyeti_pct: 7.1,
        aciklama: "Brisa taksit takvimi: Tem/Ağu/Eyl faturası → 18 Kas + 16 Ara. " +
                  "Eki/Kas/Ara faturası → 22 Oca + 22 Şub. Fark 65 gün. %40/yıl sermaye → %7,1. " +
                  "⚠ Ödeme tarihleri takvime çakılı: Temmuz'da mal alsan bile Kasım'a kadar para çıkmıyor. " +
                  "Stoğu tedarikçi finanse ediyor. Tek maliyet 65 gün erken ödeme.",
        kesin_siparis_tanimli: tesvikVar,
        karar: tesvikVar
          ? "Kesin sipariş primi > %7,1 olan markalarda ERKEN AL."
          : "⚠ kesin_siparis_pct HİÇBİR MARKADA TANIMLI DEĞİL (hepsi 0.00). " +
            "Bu alan doldurulmadan 'erken al / bekle' kararı verilemez. " +
            "Ama stok potansiyelin %" + Math.round(100 * toplamMevcut / Math.max(hedefToplam, 1)) +
            "'i — tükenme riski primden ağır basıyor.",
        tesvikler: t.rows
      },
      temel: {
        yontem: "Talep tahmini MARKA geçmişine DEĞİL, KATEGORİ toplamına dayanır.",
        neden: "KRB 3 yıl Brisa bayisi değildi (Nisan 2026'da döndü). LASSA 2024'te 899 adet sattı — " +
               "bayi olmadığı için. O sayıyı taban alsak sıfıra yakın sipariş önerirdik.",
        olculen: "Kış sezonları (Eki-Oca): 2021-22: 38.020 · 2022-23: 40.807 · 2023-24: 29.253 · " +
                 "2024-25: 19.163 · 2025-26: 18.674. Brisa kaybı kış hacminin yarısından fazlasını götürdü.",
        agirlik: "Ebat dağılımı: bayili dönem %60 (potansiyel) + son sezon %40 (güncel profil). " +
                 "⚠ Bu bir ağırlıklandırma KARARIDIR, ölçüm değil."
      },
      kalemler: kalem
    });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}
'''

# /api/bi/pricing/ccc handler'inin HEMEN ONUNE ekle (bilinen, taze anchor)
rep('''// GET /api/bi/pricing/kpis
if (request.method === "GET" && url.pathname === "/api/bi/pricing/kpis") {''',
    YENI + '''
// GET /api/bi/pricing/kpis
if (request.method === "GET" && url.pathname === "/api/bi/pricing/kpis") {''',
    "onsiparis-endpoint")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
