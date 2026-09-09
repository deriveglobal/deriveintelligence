-- ============================================================================
-- BU-AY KANONU v3 — v_marj_cari_ay EVRENİNİ kanona hizala:
--   ESKİ: ebat IS NOT NULL  (jant/akü/yedek parça gibi lastik-olmayanları da alıyordu ~0,06M gürültü)
--   YENİ: grup_adi LIKE 'LASTIK%'  (LASTIK TUKETICI+TICARI+YENILEME(retread)+TICARI TAMIR; jant/akü/yedek HARİÇ)
-- Kolonlar AYNEN korunur (CREATE OR REPLACE → sıra/tip değişmez); yalnız WHERE filtresi kanona çekilir.
-- Marj ~%7,4 aynı kalır (yalnız ~0,06M lastik-olmayan gürültü çıkar). Finans V6 bozulmaz.
-- Calistirma:  cat kanon_cari_ay_view_v3.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

CREATE OR REPLACE VIEW v_marj_cari_ay AS
WITH sal AS (
  SELECT tenant_id::uuid tenant_id, kalem_kodu, date_trunc('month',CURRENT_DATE)::date ay,
         max(marka) marka, max(ebat) ebat, max(kategori) kategori, max(grup_adi) grup_adi,
         sum(miktar) adet, sum(satir_tutar) ciro
    FROM bi_satis_faturalari
   WHERE grup_adi LIKE 'LASTIK%' AND miktar>0 AND satir_tutar>0
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

-- DOĞRULA: kanon "bu ay" (genel + çatal) — finans V6 ile aynı kalmalı, kokpit buna çekilecek
SELECT 'genel' k, round(sum(ciro)/1e6,1) ciro_M, round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid
UNION ALL
SELECT catal, round(sum(ciro)/1e6,1), round(100*sum(brut_kar)/nullif(sum(ciro),0),1)
FROM v_marj_cari_ay WHERE tenant_id=:T::uuid GROUP BY catal ORDER BY 1;
