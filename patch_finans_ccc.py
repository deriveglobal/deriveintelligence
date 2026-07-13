#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# FINANS_CCC_V1 — /api/bi/pricing/ccc YIKILDI ve YENIDEN KURULDU.
#
# ⚠⚠ EKRANDA DURAN YALAN (olculdu):
#
#   DSO = 0,1 GUN
#     Sebep: AVG(bakiye) FROM bi_musteri_bakiye = 390.886 TL
#            Bu MUSTERI BASINA ORTALAMA bakiye (399 musteriye bolunmus),
#            TOPLAM ALACAK DEGIL. Gunluk ciroya bolununce 0,1 gun cikiyor.
#            Sistem "KRB parayi 2,4 SAATTE tahsil ediyor" diyordu.
#     GERCEK: 14,0 gun (gorunen) / 44,3 gun (acik alacak 90 gunde tahsil edilirse)
#     ⚠ SUM yerine AVG yazilmis. Tek kelime. Kimse fark etmemis.
#
#   DPO = 70,1 GUN
#     Sebep: AVG(vade_gun) — AGIRLIKSIZ. 1 TL'lik fatura ile 1M TL'lik ayni agirlikta.
#     GERCEK: 55,5 gun (tutar agirlikli, YTD 2026)
#
#   DIS (stok gunu)
#     Sebep: bi_stok_hareketleri (358.028 satir AMA 12 HAZIRAN'DA DONMUS)
#            + bi_stok_durumu (3.146 satir). Bir ay eski veriden hesapliyor.
#     GERCEK: 145,9 gun (bi_stok_anlik, 52.295 lastik, SON ALIS maliyetiyle)
#
#   Toplam etki: ekran DIS + 0,1 - 70,1 gosteriyordu -> derin NEGATIF
#                -> "bol bol nakit URETIYORUZ"
#   GERCEK: +104,5 gun (iyimser) / +134,7 gun (gercekci)
#                -> ~200-250M TL isletme sermayesi BAGLI, %90'i STOKTA
#
# YENI TEMEL (hepsi bugun yuklendi ve kapidan gecti):
#   bi_stok_anlik          2.185 SKU · 52.295 lastik · 274,2M (son alis maliyeti)
#   bi_fatura_tahsilat     175.649 fatura · tarih onarimi ERP'nin kendi kolonuyla %100 dogrulandi
#   bi_musteri_risk        38.604 muhatap · acik 238,8M · gecikmis 145,4M
#   bi_tedarikci_faturalari tutar agirlikli DPO
#
# ⚠ TASARIM: tek bir sayi DEGIL, DENKLEM gosteriyoruz. Varsayim ETIKETLI.
#   'iyimser'  = acik alacaklar yok sayilir (eski ekranin ornuk mantigi)
#   'gercekci' = acik alacak 90 gunde tahsil edilir  <- TAHMIN, veri DEGIL, boyle YAZIYOR
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ── 1) DIS: donmus hareket tablosu -> ANLIK STOK + SON ALIS MALIYETI ──
rep("""      // Days in Stock: avg(stock_value) / (daily COGS from exits)
      query(`
        WITH daily_cogs AS (
          SELECT ABS(SUM(cikis_tutari)) / $2 AS daily_cogs
          FROM bi_stok_hareketleri
          WHERE tenant_id = $1 AND belge_tarihi >= now() - interval '90 days'
            AND cikis_miktari > 0 AND ABS(birim_maliyet) > 1
        ), avg_stock AS (
          SELECT SUM(toplam_deger) AS avg_value FROM bi_stok_durumu
          WHERE tenant_id = $1 AND export_date >= now() - interval '90 days'
        )
        SELECT COALESCE(avg_value / NULLIF(daily_cogs, 0), 0) AS dis
        FROM avg_stock CROSS JOIN daily_cogs`,
        [session.tenantId, lookback]),""",
"""      // FINANS_CCC_V1 — STOK GUNU
      //   ESKI: bi_stok_hareketleri + bi_stok_durumu -> 12 HAZIRAN'DA DONMUS veri.
      //   YENI: bi_stok_anlik (52.295 lastik) x SON ALIS FIYATI.
      //   ⚠ Stok LISTE fiyatiyla degerlenmez — maliyeti %40-50 sisirir.
      //     SMM de AYNI maliyet temeliyle hesaplanir; ikisi tutarli olmali.
      query(`
        WITH son AS (
          SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
            FROM bi_tedarikci_faturalari
           WHERE tenant_id = $1::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
           ORDER BY kalem_kodu, fatura_tarihi DESC
        ), stok AS (
          SELECT COALESCE(SUM(s.adet * son.maliyet), 0) AS deger
            FROM bi_stok_anlik s JOIN son ON son.kalem_kodu = s.kalem_kodu
           WHERE s.tenant_id = $1::uuid
             AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
        ), smm AS (
          SELECT COALESCE(SUM(f.miktar * son.maliyet), 0) / 365.0 AS gunluk
            FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
           WHERE f.tenant_id = $1::text AND f.grup_adi LIKE 'LASTIK%' AND f.miktar > 0
             AND f.fatura_tarihi >= CURRENT_DATE - 365
        )
        SELECT COALESCE(stok.deger / NULLIF(smm.gunluk, 0), 0) AS dis,
               stok.deger AS stok_degeri, smm.gunluk * 365 AS yillik_smm
        FROM stok CROSS JOIN smm`,
        [session.tenantId]),""",
    "ccc-dis")


# ── 2) DSO: AVG(bakiye) FELAKETI -> GERCEK TAHSILAT TARIHLERI ──
rep("""      // Days Sales Outstanding: avg(receivables) / daily_revenue
      query(`
        WITH daily_rev AS (
          SELECT SUM(satir_tutar) / $2 AS daily_rev
          FROM bi_satis_faturalari
          WHERE tenant_id = $1::text AND fatura_tarihi >= now() - interval '90 days'
        ), avg_rec AS (
          SELECT AVG(bakiye) AS avg_rec FROM bi_musteri_bakiye
          WHERE tenant_id = $1::uuid AND export_date >= now() - interval '90 days'
        )
        SELECT COALESCE(avg_rec / NULLIF(daily_rev, 0), 0) AS dso
        FROM avg_rec CROSS JOIN daily_rev`,
        [session.tenantId, lookback]),""",
"""      // FINANS_CCC_V1 — DSO
      //   ⚠⚠ ESKI KOD: AVG(bakiye) FROM bi_musteri_bakiye = 390.886 TL
      //      Bu MUSTERI BASINA ORTALAMA bakiye (399 musteriye bolunmus), TOPLAM DEGIL.
      //      Gunluk ciroya bolununce DSO = 0,1 GUN cikiyordu.
      //      Ekran "parayi 2,4 SAATTE tahsil ediyoruz" diyordu. SUM yerine AVG.
      //   YENI: bi_fatura_tahsilat — GERCEK tahsilat tarihleri (175.649 fatura).
      //      Tarih onarimi ERP'nin KENDI 'Tahsilat Suresi' kolonuyla %100 dogrulandi.
      //
      //   ⚠ SAG KALAN YANLILIGI: tahsilat dosyasinda ACIK FATURA YOK. Yani DSO
      //     sadece TAHSIL EDILMIS faturalardan hesaplaniyor; henuz odenmemis
      //     (ve muhtemelen YAVAS odenecek) 238,8M hesabin DISINDA.
      //     Bu yuzden IKI rakam donuyoruz: gorunen ve gercekci. Gizlemiyoruz.
      query(`
        WITH t AS (
          SELECT COALESCE(SUM(fatura_tutari), 0) AS tut,
                 COALESCE(SUM(fatura_tutari * tahsilat_gun), 0) AS agir
            FROM bi_fatura_tahsilat
           WHERE tenant_id = $1::uuid AND tahsilat_gun IS NOT NULL
             AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
        ), r AS (
          SELECT COALESCE(SUM(toplam_risk), 0)   AS acik,
                 COALESCE(SUM(vadesi_gecmis), 0) AS gecikmis
            FROM bi_musteri_risk
           WHERE tenant_id = $1::uuid AND musteri_mi
             AND export_date = (SELECT MAX(export_date) FROM bi_musteri_risk WHERE tenant_id = $1::uuid)
        )
        SELECT COALESCE(t.agir / NULLIF(t.tut, 0), 0)                                  AS dso,
               COALESCE((t.agir + r.acik * 90) / NULLIF(t.tut + r.acik, 0), 0)          AS dso_gercekci,
               r.acik AS acik_alacak, r.gecikmis AS gecikmis_alacak
        FROM t CROSS JOIN r`,
        [session.tenantId]),""",
    "ccc-dso")


# ── 3) DPO: AGIRLIKSIZ ORTALAMA -> TUTAR AGIRLIKLI ──
rep("""      // Days Payable Outstanding: avg(AP balance) / daily_COGS
      query(`
        SELECT COALESCE(AVG(vade_gun), 0) AS dpo
        FROM bi_tedarikci_faturalari
        WHERE tenant_id = $1
          AND fatura_tarihi >= now() - interval '90 days'
          AND vade_gun > 0`,""",
"""      // FINANS_CCC_V1 — DPO
      //   ESKI: AVG(vade_gun) = AGIRLIKSIZ. 1 TL'lik fatura ile 1M TL'lik esit agirlikta.
      //         70,1 gun gosteriyordu.
      //   YENI: TUTAR AGIRLIKLI -> 55,5 gun (YTD 2026). Nakit neyi bekliyorsa o.
      //   ⚠ miktar > 0: iade faturalari (negatif miktar) vadeyi TERS agirliklandirir.
      query(`
        SELECT COALESCE(
                 SUM(satir_kdv_haric * vade_gun) / NULLIF(SUM(satir_kdv_haric), 0), 0
               ) AS dpo
        FROM bi_tedarikci_faturalari
        WHERE tenant_id = $1::uuid
          AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
          AND vade_gun > 0 AND miktar > 0 AND satir_kdv_haric > 0`,""",
    "ccc-dpo")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
