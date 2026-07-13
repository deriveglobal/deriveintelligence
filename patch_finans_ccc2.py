#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# FINANS_CCC_V2 — handler kuyrugu: DONMUS maliyet + EKSIK yanit govdesi.
#
# V1 sorgulari duzeltti ama handler'in KUYRUGU iki sey daha saklıyordu:
#
# 1) avgCost hala bi_stok_hareketleri'nden okuyor -> 12 HAZIRAN'DA DONMUS.
#    Birim finansman maliyeti bir aylik eski maliyetle hesaplaniyor.
#    -> bi_stok_anlik x SON ALIS FIYATI (agirlikli) ile degistiriliyor.
#
# 2) sendJson sadece dis/dso/dpo/ccc donduruyor. V1'de urettigimiz
#    dso_gercekci / acik_alacak / stok_degeri DISARI CIKMIYOR.
#    -> Ekran tek bir sayi gorur, DENKLEMI gormez. Varsayimi etiketleme
#       amacimiz tam orada olur. Butun govdeyi aciyoruz.
#
# ⚠ TASARIM: 'gercekci' senaryo bir TAHMINDIR (acik alacak 90 gunde tahsil).
#   Yanitta 'varsayim' alaniyla ACIKCA yaziyor. Veri gibi sunulmuyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ── 1) DONMUS maliyet -> anlik stok + son alis ──
rep("""    // Average purchase price for real margin calc
    const avgCost = await query(`
      SELECT AVG(birim_maliyet) AS avg_cost
      FROM bi_stok_hareketleri
      WHERE tenant_id = $1 AND belge_tarihi >= now() - interval '30 days'
        AND birim_maliyet > 1`, [session.tenantId]);
    const avg_cost = parseFloat(avgCost.rows[0]?.avg_cost || 0);""",
"""    // FINANS_CCC_V2 — ortalama birim maliyet
    //   ESKI: bi_stok_hareketleri (12 HAZIRAN'DA DONMUS) son 30 gun -> bos/bayat.
    //   YENI: elimizdeki stogun GERCEK agirlikli maliyeti (adet x son alis fiyati).
    //   ⚠ Duz AVG degil ADET AGIRLIKLI: 1 adet is makinesi lastigi (137.000 TL) ile
    //     500 adet binek lastigi (4.000 TL) esit agirlikta olamaz.
    const avgCost = await query(`
      WITH son AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
          FROM bi_tedarikci_faturalari
         WHERE tenant_id = $1::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
         ORDER BY kalem_kodu, fatura_tarihi DESC
      )
      SELECT COALESCE(SUM(s.adet * son.maliyet) / NULLIF(SUM(s.adet), 0), 0) AS avg_cost
        FROM bi_stok_anlik s JOIN son ON son.kalem_kodu = s.kalem_kodu
       WHERE s.tenant_id = $1::uuid AND s.adet > 0
         AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)`,
      [session.tenantId]);
    const avg_cost = parseFloat(avgCost.rows[0]?.avg_cost || 0);""",
    "ccc-avgcost")


# ── 2) Yanit govdesi: DENKLEMI ac, varsayimi ETIKETLE ──
rep("""    sendJson(response, 200, {
      lookback_days: lookback,
      dis: Math.round(dis_days * 10) / 10,
      dso: Math.round(dso_days * 10) / 10,
      dpo: Math.round(dpo_days * 10) / 10,
      ccc: Math.round(ccc * 10) / 10,
      cost_of_capital: costOfCapital,
      avg_unit_cost: Math.round(avg_cost * 100) / 100,
      financing_cost_per_unit: Math.round(financing_cost_per_unit * 100) / 100,
      note: dpo_days < 1 ? "DPO incomplete — payment dates pending from IT (blocking)" : null
    });""",
"""    // FINANS_CCC_V2 — DENKLEMI ac. Tek sayi degil, VARSAYIMLARIYLA tablo.
    const dso_gercekci = parseFloat(dso.rows[0]?.dso_gercekci || 0);
    const acik_alacak  = parseFloat(dso.rows[0]?.acik_alacak || 0);
    const gecikmis     = parseFloat(dso.rows[0]?.gecikmis_alacak || 0);
    const stok_degeri  = parseFloat(dis.rows[0]?.stok_degeri || 0);
    const yillik_smm   = parseFloat(dis.rows[0]?.yillik_smm || 0);
    const ccc_gercekci = dis_days + dso_gercekci - dpo_days;
    const gunluk_smm   = yillik_smm / 365;

    sendJson(response, 200, {
      // ── DENKLEM: dongu = stok gunu + DSO − DPO
      dis: Math.round(dis_days * 10) / 10,
      dso: Math.round(dso_days * 10) / 10,
      dpo: Math.round(dpo_days * 10) / 10,
      ccc: Math.round(ccc * 10) / 10,

      // ── GERCEKCI SENARYO — ⚠ TAHMIN, VERI DEGIL
      dso_gercekci: Math.round(dso_gercekci * 10) / 10,
      ccc_gercekci: Math.round(ccc_gercekci * 10) / 10,
      varsayim: "Gercekci senaryo, acik alacagin (" +
                Math.round(acik_alacak / 1e6) + "M TL) 90 GUNDE tahsil edilecegini VARSAYAR. " +
                "Bu bir TAHMINDIR, olculmus veri DEGILDIR. Gorunen DSO sadece TAHSIL EDILMIS " +
                "faturalari kapsar; henuz odenmemis (ve muhtemelen daha yavas odenecek) alacak " +
                "hesabin disindadir.",

      // ── BAGLI PARA
      stok_degeri: Math.round(stok_degeri),
      acik_alacak: Math.round(acik_alacak),
      gecikmis_alacak: Math.round(gecikmis),
      bagli_sermaye: Math.round(gunluk_smm * ccc),
      bagli_sermaye_gercekci: Math.round(gunluk_smm * ccc_gercekci),
      yillik_smm: Math.round(yillik_smm),

      // ── FINANSMAN
      cost_of_capital: costOfCapital,
      avg_unit_cost: Math.round(avg_cost * 100) / 100,
      financing_cost_per_unit: Math.round(financing_cost_per_unit * 100) / 100,
      yillik_finansman_maliyeti: Math.round(gunluk_smm * ccc * costOfCapital),

      // ── KAYNAK SEFFAFLIGI — hangi tablodan, ne zaman
      kaynaklar: {
        stok: "bi_stok_anlik (son alis maliyetiyle degerlendi — LISTE ile DEGIL)",
        dso: "bi_fatura_tahsilat (gercek tahsilat tarihleri; tarih onarimi ERP'nin kendi kolonuyla %100 dogrulandi)",
        dpo: "bi_tedarikci_faturalari (TUTAR AGIRLIKLI — duz ortalama DEGIL)",
        acik_alacak: "bi_musteri_risk (tedarikci/personel/grup HARIC — sadece musteri)"
      },

      // ── EKSIK PARCA — gizlemiyoruz
      eksik: dis_days > 0 ? null :
             "Stok gunu hesaplanamadi — bi_stok_anlik bos ya da maliyet eslesmesi yok.",
      note: ccc > 0
        ? "Nakit dongusu POZITIF: parayi tahsil etmeden ONCE tedarikciye oduyoruz. " +
          "Her gun isletme sermayesi baglar."
        : "Nakit dongusu NEGATIF: tedarikciye odemeden once parayi aliyoruz."
    });""",
    "ccc-yanit")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
