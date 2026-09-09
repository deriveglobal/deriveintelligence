-- ============================================================================
-- BU-AY KANONU — v_marj_cari_ay : cari (kısmi) ayın marjı, ATOM'la AYNI akış yöntemi.
-- Atom cari ayı tutmaz (fatura_tarihi < ay_başı); bu view onu CANLI doldurur (her okumada taze).
-- Hem finans "bu ay" hem kokpit "bu ay" BUNU okuyacak → tek kaynak, tutarlı.
-- Teşvik ÖNCESİ brüt (kanon headline). Additive (CREATE OR REPLACE VIEW) — hiçbir şeyi bozmaz.
-- Çalıştırma:  cat kanon_cari_ay_view.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

CREATE OR REPLACE VIEW v_marj_cari_ay AS
WITH sal AS (
  SELECT tenant_id::uuid tenant_id, kalem_kodu, date_trunc('month',CURRENT_DATE)::date ay,
         max(marka) marka, max(ebat) ebat, max(kategori) kategori,
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
       c.kapsam kanon_kapsam
  FROM sal s JOIN cost c USING (tenant_id, kalem_kodu);

-- DOĞRULA 1: cari ay (lastik) ciro-ağırlıklı marj + kapsam
SELECT round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) buay_lastik_marj,
       count(*) sku, round(sum(ciro)/1e6,1) ciro_M, round(avg(kanon_kapsam)) ort_kapsam
FROM v_marj_cari_ay WHERE tenant_id = :T::uuid;

-- DOĞRULA 2: Bridgestone cari ay (kanon akış maliyetiyle)
SELECT kalem_kodu, adet, ort_fiyat, birim_maliyet, marj_pct, kanon_kapsam
FROM v_marj_cari_ay WHERE tenant_id = :T::uuid AND marka='BRIDGESTONE'
ORDER BY ciro DESC LIMIT 6;

-- DOĞRULA 3: çatal (tüketici/ticari) cari ay marjı — kokpit "bu ay" çatalı buradan gelecek
SELECT CASE WHEN kategori_segment(kategori)='PSR' THEN 'TUK' ELSE 'TIC' END umb,
       round(sum(ciro)/1e6,1) ciro_M, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj
FROM v_marj_cari_ay WHERE tenant_id = :T::uuid GROUP BY 1;
