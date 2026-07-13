#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# AYKIRI_V1 — aykiri satislari araliktan CIKAR, ama GIZLEME.
#
# SORUN (canli veriden): BRIDGESTONE 385/65R22.5
#   min 339 TL · medyan 18.125 TL · max 21.250 TL
#   339 TL bir satis degil -- numune, garanti degisimi ya da giris hatasi.
#   Ama MIN() oldugu icin ekranda "en ucuz 339'a sattik" yazacakti ve
#   onaylayan buna gore karar verseydi sacma bir fiyat cikardi.
#
# COZUM (Fatih'in karari):
#   • Medyanin %30'unun ALTINDAKI satislar araligin disinda tutulur.
#   • Kac tanesinin cikarildigi ACIKCA yazilir.
#   • TIKLAYINCA hangileri oldugu gorunur: musteri, fiyat, tarih, fatura no.
#   Sessizce filtrelemek yok. Bugunun butun dersi bu.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ── /analiz: medyani once hesapla, sonra aykirilari ayir
rep("""          if (k.ebat && k.marka) {
            const _ks = await pool.query(
              "SELECT COUNT(*)::int AS n, SUM(miktar)::numeric AS adet, " +
              "  ROUND(MIN(birim_fiyat)) AS mn, ROUND(MAX(birim_fiyat)) AS mx, " +
              "  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS med, " +
              "  (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1]  AS en_ucuz_musteri, " +
              "  (array_agg(birim_fiyat ORDER BY birim_fiyat ASC))[1]  AS en_ucuz_fiyat, " +
              "  (array_agg(fatura_tarihi ORDER BY birim_fiyat ASC))[1] AS en_ucuz_tarih, " +
              "  (array_agg(musteri_adi ORDER BY birim_fiyat DESC))[1] AS en_pahali_musteri, " +
              "  (array_agg(birim_fiyat ORDER BY birim_fiyat DESC))[1] AS en_pahali_fiyat, " +
              "  (array_agg(fatura_tarihi ORDER BY birim_fiyat DESC))[1] AS en_pahali_tarih " +
              " FROM bi_satis_faturalari " +
              " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
              "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 " +
              "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",
              [session.tenantId, k.ebat, k.marka]);
            const g = _ks.rows[0];
            if (g && Number(g.n) > 0) {
              _kendi = {
                satis_adedi: Number(g.n), toplam_adet: _num(g.adet),
                min: _num(g.mn), medyan: _num(g.med), max: _num(g.mx),
                en_ucuz:   { musteri: g.en_ucuz_musteri,   fiyat: _num(g.en_ucuz_fiyat),   tarih: g.en_ucuz_tarih },
                en_pahali: { musteri: g.en_pahali_musteri, fiyat: _num(g.en_pahali_fiyat), tarih: g.en_pahali_tarih },
                donem: 'bu_yil'
              };
            }
          }""",
"""          if (k.ebat && k.marka) {
            // AYKIRI_V1 — once MEDYAN, sonra aykiri esigi (medyanin %30'u).
            //   339 TL'lik bir "satis" (medyan 18.125) numune/garanti/hata olabilir.
            //   Araligi kirletir. Cikariyoruz ama SAKLAMIYORUZ: kac tane oldugunu
            //   yaziyoruz ve tiklaninca hepsini gosteriyoruz.
            const _AYKIRI_ORAN = 0.30;
            const _med0 = await pool.query(
              "SELECT ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS med, " +
              "       COUNT(*)::int AS n " +
              " FROM bi_satis_faturalari " +
              " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
              "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 " +
              "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",
              [session.tenantId, k.ebat, k.marka]);
            const _medyan = _num(_med0.rows[0] && _med0.rows[0].med);
            const _esik = _medyan != null ? _medyan * _AYKIRI_ORAN : 0;

            if (_medyan != null && Number(_med0.rows[0].n) > 0) {
              // (a) TEMIZ aralik — aykirilar HARIC
              const _ks = await pool.query(
                "SELECT COUNT(*)::int AS n, SUM(miktar)::numeric AS adet, " +
                "  ROUND(MIN(birim_fiyat)) AS mn, ROUND(MAX(birim_fiyat)) AS mx, " +
                "  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS med, " +
                "  (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1]  AS en_ucuz_musteri, " +
                "  (array_agg(birim_fiyat ORDER BY birim_fiyat ASC))[1]  AS en_ucuz_fiyat, " +
                "  (array_agg(fatura_tarihi ORDER BY birim_fiyat ASC))[1] AS en_ucuz_tarih, " +
                "  (array_agg(musteri_adi ORDER BY birim_fiyat DESC))[1] AS en_pahali_musteri, " +
                "  (array_agg(birim_fiyat ORDER BY birim_fiyat DESC))[1] AS en_pahali_fiyat, " +
                "  (array_agg(fatura_tarihi ORDER BY birim_fiyat DESC))[1] AS en_pahali_tarih " +
                " FROM bi_satis_faturalari " +
                " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
                "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat >= $4 " +
                "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",
                [session.tenantId, k.ebat, k.marka, _esik]);

              // (b) AYKIRILAR — tam liste, tiklaninca gosterilecek
              const _ay = await pool.query(
                "SELECT musteri_adi, birim_fiyat, fatura_tarihi, fatura_no, miktar, satis_temsilcisi " +
                " FROM bi_satis_faturalari " +
                " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
                "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 AND birim_fiyat < $4 " +
                "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE) " +
                " ORDER BY birim_fiyat ASC LIMIT 50",
                [session.tenantId, k.ebat, k.marka, _esik]);

              const g = _ks.rows[0];
              if (g && Number(g.n) > 0) {
                _kendi = {
                  satis_adedi: Number(g.n), toplam_adet: _num(g.adet),
                  min: _num(g.mn), medyan: _num(g.med), max: _num(g.mx),
                  en_ucuz:   { musteri: g.en_ucuz_musteri,   fiyat: _num(g.en_ucuz_fiyat),   tarih: g.en_ucuz_tarih },
                  en_pahali: { musteri: g.en_pahali_musteri, fiyat: _num(g.en_pahali_fiyat), tarih: g.en_pahali_tarih },
                  donem: 'bu_yil',
                  // ⚠ ARALIK DISINDA TUTULANLAR — gizlenmiyor, listeleniyor.
                  aykiri_esigi: Math.round(_esik),
                  aykiri_sayisi: _ay.rowCount,
                  aykirilar: _ay.rows.map(function (x) {
                    return { musteri: x.musteri_adi, fiyat: _num(x.birim_fiyat),
                             tarih: x.fatura_tarihi, fatura_no: x.fatura_no,
                             adet: _num(x.miktar), temsilci: x.satis_temsilcisi };
                  })
                };
              }
            }
          }""",
    "analiz-aykiri")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
