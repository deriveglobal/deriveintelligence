# -*- coding: utf-8 -*-
# SON10_ALIS_V1 — teklif kalem zenginlestirmesine EK VERI:
#   (1) son_alanlar = bu urunu (ebat+marka) bu yil alan SON 10 musteri (isim, fiyat, tarih)
#   (2) kendi_alis  = bu urunu (kalem_kodu) bu yil kaca ALDIK: min/medyan/max (YTD)
#   Render tarafi (saha.js) ayri yamada gosterir. Mevcut alanlar korunur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SON10_ALIS_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) Hesap blogu — teklif_v2 catch'inden SONRA, push'tan ONCE
OLD1 = "        } catch (e) { console.error('[teklif_v2] analiz:', e && e.message); }"
NEW1 = OLD1 + '''

        // SON10_ALIS_V1 — son 10 alan musteri + bu yil alis min/medyan/max
        let _sonAlanlar = null, _kendiAlis = null;
        try {
          if (k.ebat && k.marka) {
            const _s10 = await pool.query(
              "SELECT musteri_adi, ROUND(birim_fiyat) AS fiyat, fatura_tarihi FROM (" +
              "  SELECT DISTINCT ON (musteri_adi) musteri_adi, birim_fiyat, fatura_tarihi" +
              "    FROM bi_satis_faturalari" +
              "   WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3)" +
              "     AND grup_adi LIKE 'LASTIK%' AND birim_fiyat>0 AND miktar>0" +
              "     AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)" +
              "   ORDER BY musteri_adi, fatura_tarihi DESC) q" +
              " ORDER BY fatura_tarihi DESC LIMIT 10",
              [session.tenantId, k.ebat, k.marka]);
            if (_s10.rowCount) _sonAlanlar = _s10.rows.map(function (x) {
              return { musteri: x.musteri_adi, fiyat: _num(x.fiyat), tarih: x.fatura_tarihi };
            });
          }
          if (k.kalem_kodu) {
            const _ad = await pool.query(
              "SELECT ROUND(MIN(birim_fiyat_kdv_haric)) AS mn," +
              "  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat_kdv_haric)::numeric) AS med," +
              "  ROUND(MAX(birim_fiyat_kdv_haric)) AS mx, COUNT(*)::int AS n" +
              " FROM bi_tedarikci_faturalari" +
              " WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric>0 AND miktar>0" +
              "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",
              [session.tenantId, k.kalem_kodu]);
            const a2 = _ad.rows[0];
            if (a2 && Number(a2.n) > 0) _kendiAlis = {
              min: _num(a2.mn), medyan: _num(a2.med), max: _num(a2.mx),
              alis_adedi: Number(a2.n), donem: 'bu_yil'
            };
          }
        } catch (e) { console.error('[son10_alis]', e && e.message); }'''
assert s.count(OLD1) == 1, "catch anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) push'a yeni alanlari ekle
OLD2 = "          kendi_satis: _kendi, agirlikli: _agir,"
NEW2 = "          kendi_satis: _kendi, agirlikli: _agir, son_alanlar: _sonAlanlar, kendi_alis: _kendiAlis,  /* SON10_ALIS_V1 */"
assert s.count(OLD2) == 1, "push anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SON10_ALIS_V1 (server)")
