-- ============================================================================
-- BU-AY KANONU v2 — v_marj_cari_ay'e grup_adi + catal kolonlari EKLE (additive).
-- Amac: kokpit "bu ay" bloğu (_clm) bu view'i okusun; evrensel (ciro) taban birebir olsun.
-- CREATE OR REPLACE VIEW: mevcut kolonlar AYNEN korunur, yeni kolonlar SONA eklenir → finans V6 bozulmaz.
-- Calistirma:  cat kanon_cari_ay_view_v2.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

CREATE OR REPLACE VIEW v_marj_cari_ay AS
WITH sal AS (
  SELECT tenant_id::uuid tenant_id, kalem_kodu, date_trunc('month',CURRENT_DATE)::date ay,
         max(marka) marka, max(ebat) ebat, max(kategori) kategori, max(grup_adi) grup_adi,
         sum(miktar) adet, sum(satir_tutar) ciro
    FROM bi_satis_faturalari
   WHERE ebat IS NOT NULL AND miktar>0 AND satir_tutar>0
     AND fatura_tarihi >= date_trunc('month',CURRENT_DATE)
   GROUP BY tenant_id, kalem_kodu
),
lots AS (
  SELECT s.tenant_id, s.kalem_kodu, s.adet::numeric sold_qty, h.giris::numeric giris,
         (h.giris_tutari/NULLIF(h.giris,0))::numeric uc,
         sum(h.giris) OVER (PARTITION BY s.tenant_id, s.kalem_kodu
                            ORDER BY h.belge_tarihi DESC, h.ctid DESC
                            ROWS UNBOUNDED PRECEDING) run
    FROM sal s
    JOIN bi_stok_hareket h
      ON h.tenant_id=s.tenant_id AND h.kalem_kodu=s.kalem_kodu
     AND h.hareket_sinifi IN ('MAL_GIRISI','ACILIS')
     AND h.giris>0 AND h.giris_tutari>0
),
used AS (
  SELECT tenant_id, kalem_kodu, sold_qty, uc,
         greatest(0, least(giris, sold_qty-(run-giris)))::numeric uq
    FROM lots
),
cost AS (
  SELECT tenant_id, kalem_kodu, sum(uc*uq)/NULLIF(sum(uq),0) mc,
         round(100*sum(uq)/NULLIF(max(sold_qty),0)) kapsam
    FROM used WHERE uq>0 GROUP BY 1,2
)
SELECT s.tenant_id, s.kalem_kodu, s.ay, s.marka, s.ebat, s.kategori,
       s.adet, s.ciro,
       round(s.ciro/NULLIF(s.adet,0)) ort_fiyat,
       round(c.mc) birim_maliyet,
       round(s.ciro - s.adet*c.mc) brut_kar,
       round(100*(s.ciro - s.adet*c.mc)/NULLIF(s.ciro,0),1) marj_pct,
       c.kapsam kanon_kapsam,
       s.grup_adi,
       CASE WHEN kategori_segment(s.kategori)='PSR' THEN 'TUK' ELSE 'TIC' END catal
  FROM sal s JOIN cost c USING (tenant_id, kalem_kodu);

-- ============ EVREN KARSILASTIRMASI (kokpit birebir olacak mi?) ============
-- A) view TOPLAM (tum ebat-not-null) = finans "bu ay" %7,4 tabani
SELECT 'A_view_toplam(ebat)' etiket,
       round(sum(ciro)/1e6,1) ciro_M, round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid;

-- B) view, YALNIZ grup_adi IN (LASTIK TUKETICI/TICARI) = kokpit _clm evreni
SELECT 'B_view_grupadi2' etiket,
       round(sum(ciro)/1e6,1) ciro_M, round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI');
-- (A ile B ayni ise evren AYNI → kokpit birebir %7,4 olur. Farkliysa aradaki fark = grup_adi disi ebat'li SKU.)

-- C) view'deki TUM grup_adi degerleri (grup_adi disinda ebat'li satis var mi?)
SELECT coalesce(grup_adi,'(bos)') grup_adi, round(sum(ciro)/1e6,2) ciro_M, count(*) sku
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid GROUP BY 1 ORDER BY 2 DESC;

-- D) CATAL — grup_adi bazli (kokpitin mevcut yontemi) vs kategori_segment bazli (kanon)
SELECT 'grupadi' yontem,
       round(100*sum(brut_kar) FILTER (WHERE grup_adi='LASTIK TUKETICI')/nullif(sum(ciro) FILTER (WHERE grup_adi='LASTIK TUKETICI'),0),1) tuk,
       round(100*sum(brut_kar) FILTER (WHERE grup_adi='LASTIK TICARI')/nullif(sum(ciro) FILTER (WHERE grup_adi='LASTIK TICARI'),0),1) tic,
       round(sum(ciro) FILTER (WHERE grup_adi='LASTIK TUKETICI')/1e6,1) tuk_ciro_M,
       round(sum(ciro) FILTER (WHERE grup_adi='LASTIK TICARI')/1e6,1) tic_ciro_M
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid
UNION ALL
SELECT 'kategori_segment',
       round(100*sum(brut_kar) FILTER (WHERE catal='TUK')/nullif(sum(ciro) FILTER (WHERE catal='TUK'),0),1),
       round(100*sum(brut_kar) FILTER (WHERE catal='TIC')/nullif(sum(ciro) FILTER (WHERE catal='TIC'),0),1),
       round(sum(ciro) FILTER (WHERE catal='TUK')/1e6,1),
       round(sum(ciro) FILTER (WHERE catal='TIC')/1e6,1)
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid;
