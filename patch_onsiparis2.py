#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ONSIPARIS_V2 — EBAT ESLESTIRMESI DUZELTILDI + MALIYET KAPSAMI GORUNUR.
#
# ⚠ V1'DE IKI KUSUR VARDI, IKISI DE "MAKUL GORUNEN SESSIZ YANLIS" TURUNDEN:
#
#   1) EBAT'i kalem_tanimi'ndan REGEX ile cikariyordum.
#      bi_stok_anlik'ta ebat kolonu YOKTU (kaynak dosyada da yoktu).
#      Satis tablosundaki 'ebat' alaniyla birebir TUTMUYORDU.
#      Kanit: 175/70R13 mevcut stok "1 adet" gorunuyordu — gercekte
#      baska bir kalipta yazilmis olabilir. Yani EBAT BAZINDA MEVCUT STOK
#      GUVENILMEZDI ve model "eksik" hesabini yanlis yapiyordu.
#      -> COZUM: ebat, kalem_kodu uzerinden ERP'nin KENDI alanindan gelir.
#         Regex YOK. Tahmin YOK.
#
#   2) 215/75R16C'nin birim maliyeti 0 idi (alis faturasi eslesmemis).
#      tutar = 0 x adet = 0. Yani o satir SESSIZCE HESABIN DISINDA kaldi.
#      -> COZUM: maliyet eslesmeyen satirlar 'maliyet_yok' bayragiyla
#         DONULUYOR ve toplamda AYRI gosteriliyor. Gizlenmiyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ── stok CTE: regex YOK, kalem_kodu -> ebat (ERP'nin kendi alani) ──
rep("""      stok AS (
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
       LIMIT 60`,""",
"""      -- ONSIPARIS_V2: EBAT, kalem_kodu uzerinden ERP'nin KENDI alanindan.
      --   ⚠ V1'de kalem_tanimi'ndan REGEX ile cikariliyordu -> satis tablosunun
      --     'ebat' alaniyla tutmuyordu -> mevcut stok YANLIS, eksik hesabi YANLIS.
      --     Regex ile ebat cikarmak, bugun 7 kez yakaladigimiz hatanin aynisi:
      --     makul gorunen, sessizce yanlis bir sayi.
      kod_ebat AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND ebat IS NOT NULL AND ebat <> ''
         ORDER BY kalem_kodu, fatura_tarihi DESC
      ),
      stok AS (
        SELECT ke.ebat AS ebat,
               SUM(s.adet) AS mevcut,
               SUM(s.adet * m.maliyet) / NULLIF(SUM(s.adet) FILTER (WHERE m.maliyet IS NOT NULL), 0) AS birim_maliyet,
               SUM(s.adet) FILTER (WHERE m.maliyet IS NULL) AS maliyetsiz_adet
          FROM bi_stok_anlik s
          JOIN kod_ebat ke      ON ke.kalem_kodu = s.kalem_kodu
          LEFT JOIN son_maliyet m ON m.kalem_kodu = s.kalem_kodu
         WHERE s.tenant_id = $1::uuid AND s.adet > 0 AND s.sezon ILIKE $2
           AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
         GROUP BY 1
      ),
      -- ⚠ Ebat basina maliyet: stokta yoksa SATIS tarafindaki ayni ebatin
      --   son alis maliyetinden turet. Yoksa NULL — SIFIR DEGIL.
      --   Sifir yazmak, o satiri sessizce hesabin disinda birakir.
      ebat_maliyet AS (
        SELECT sf.ebat, AVG(m.maliyet) AS maliyet
          FROM bi_satis_faturalari sf JOIN son_maliyet m ON m.kalem_kodu = sf.kalem_kodu
         WHERE sf.tenant_id = $1::text AND sf.grup_adi LIKE 'LASTIK%'
           AND sf.kategori ILIKE $2 AND sf.ebat <> ''
           AND sf.fatura_tarihi >= CURRENT_DATE - 730
         GROUP BY 1
      )
      SELECT p.ebat,
             ROUND(p.oran * 100, 2)                     AS talep_pay_pct,
             ROUND($3 * p.oran)                         AS hedef_adet,
             COALESCE(ROUND(st.mevcut), 0)              AS mevcut_stok,
             GREATEST(ROUND($3 * p.oran) - COALESCE(st.mevcut, 0), 0) AS eksik_adet,
             ROUND(COALESCE(st.birim_maliyet, em.maliyet))  AS birim_maliyet,
             ROUND(GREATEST(ROUND($3 * p.oran) - COALESCE(st.mevcut, 0), 0)
                   * COALESCE(st.birim_maliyet, em.maliyet)) AS tutar,
             -- ⚠ SEFFAFLIK: maliyet nereden geldi? Bilinmiyorsa SOYLE.
             CASE WHEN st.birim_maliyet IS NOT NULL THEN 'stok_son_alis'
                  WHEN em.maliyet IS NOT NULL       THEN 'ebat_ortalamasi'
                  ELSE 'MALIYET_YOK' END             AS maliyet_kaynagi,
             COALESCE(st.maliyetsiz_adet, 0)           AS maliyetsiz_adet
        FROM pay p
        LEFT JOIN stok st          ON st.ebat = p.ebat
        LEFT JOIN ebat_maliyet em  ON em.ebat = p.ebat
       WHERE p.oran > 0.001
       ORDER BY p.oran DESC
       LIMIT 60`,""",
    "v2-ebat-eslestirme")


# ── Cikti: maliyet kaynagini ve bilinmeyen satirlari GORUNUR yap ──
rep("""    const kalem = r.rows.map(x => ({
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
    }));""",
"""    const kalem = r.rows.map(x => ({
      ebat: x.ebat,
      talep_pay_pct: Number(x.talep_pay_pct),
      hedef: Number(x.hedef_adet),
      mevcut: Number(x.mevcut_stok),
      eksik: Number(x.eksik_adet),
      birim_maliyet: x.birim_maliyet == null ? null : Number(x.birim_maliyet),
      tutar: x.tutar == null ? null : Number(x.tutar),
      // ⚠ ONSIPARIS_V2 — maliyet NEREDEN geldi? Bilinmiyorsa TUTAR YOK, SIFIR DEGIL.
      maliyet_kaynagi: x.maliyet_kaynagi,
      durum: Number(x.mevcut_stok) === 0 ? "yok"
           : Number(x.mevcut_stok) < Number(x.hedef_adet) * 0.3 ? "kritik"
           : Number(x.mevcut_stok) < Number(x.hedef_adet) * 0.7 ? "eksik" : "yeterli"
    }));
    // ⚠ Maliyeti BILINMEYEN satirlar: toplama katilmaz, AYRI raporlanir.
    const maliyetsiz = kalem.filter(k => k.maliyet_kaynagi === "MALIYET_YOK");""",
    "v2-maliyet-seffaflik")


rep("""    const toplamEksik = kalem.reduce((a, k) => a + k.eksik, 0);
    const toplamTutar = kalem.reduce((a, k) => a + k.tutar, 0);
    const toplamMevcut = kalem.reduce((a, k) => a + k.mevcut, 0);""",
"""    const toplamEksik  = kalem.reduce((a, k) => a + k.eksik, 0);
    const toplamTutar  = kalem.reduce((a, k) => a + (k.tutar || 0), 0);
    const toplamMevcut = kalem.reduce((a, k) => a + k.mevcut, 0);
    // ⚠ Maliyeti bilinmeyen adet — TUTAR bu kadar EKSIK hesaplanmis olabilir.
    const bilinmeyenAdet = maliyetsiz.reduce((a, k) => a + k.eksik, 0);""",
    "v2-toplamlar")


rep("""      ozet: {
        hedef_toplam: hedefToplam,
        mevcut_stok: toplamMevcut,
        eksik_adet: toplamEksik,
        tahmini_tutar: toplamTutar,
        karsilama_pct: Math.round(100 * toplamMevcut / Math.max(hedefToplam, 1))
      },""",
"""      ozet: {
        hedef_toplam: hedefToplam,
        mevcut_stok: toplamMevcut,
        eksik_adet: toplamEksik,
        tahmini_tutar: toplamTutar,
        karsilama_pct: Math.round(100 * toplamMevcut / Math.max(hedefToplam, 1)),
        // ⚠ EKSIK OLANI GIZLEME
        maliyeti_bilinmeyen_adet: bilinmeyenAdet,
        maliyet_uyarisi: bilinmeyenAdet > 0
          ? bilinmeyenAdet + " adette birim maliyet bilinmiyor (alış faturası eşleşmedi). " +
            "Tahmini tutar BU KADAR EKSİK. Sıfır yazıp gizlemiyoruz."
          : null
      },""",
    "v2-ozet-uyari")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
