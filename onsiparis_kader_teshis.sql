-- ÖN-SİPARİŞ KADERİ teşhis (READ-ONLY) — amiral gemisi kanıtı.
-- 2026-27 KIS ön-sipariş taahhüdü, KRB'nin o marka+ebatı geçmiş 2 kışta (Eki-Şub) gerçekte sattığına karşı.
-- Taahhüt/geçmiş oranı > 1,5 = aşırı bağlama riski (beklenen ölü stok + maliyet-altı). Sezon OLMADAN uyarı.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '################ 1) ÖN-SİPARİŞ KİTABI — hangi sezonlar var, hacim ################'
SELECT sezon_yili, sezon, count(*) satir, round(sum(adet)) adet,
       round(sum(adet*liste_kdvdahil)/1e6,1) tl_m, count(DISTINCT marka) marka, count(DISTINCT ebat) ebat, count(DISTINCT alici) alici_say
  FROM bi_on_siparis WHERE tenant_id::text=:'t' GROUP BY 1,2 ORDER BY 1,2;

\echo '################ 1b) ALICI kırılımı (KRB kendi mi, müşteri taahhüdü mü) — 2026-27 KIS ################'
SELECT alici, round(sum(adet)) adet, round(sum(adet*liste_kdvdahil)/1e6,1) tl_m, count(DISTINCT marka||ebat) satir
  FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS'
 GROUP BY 1 ORDER BY adet DESC;

\echo '################ 2) TAAHHÜT — 2026-27 KIS, marka bazında (adet + liste ₺) ################'
SELECT marka, round(sum(adet)) commit_adet, round(sum(adet*liste_kdvdahil)/1e6,1) commit_tl_m,
       round(sum(adet) FILTER (WHERE upper(alici) LIKE 'KRB%')) krb_kendi_adet
  FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS'
 GROUP BY 1 ORDER BY commit_adet DESC;

\echo '################ 3) KADER TESTİ — taahhüt vs geçmiş kış fiili satış (marka+ebat) ################'
\echo '    ratio = commit / gecen_kis ; >1,5 = aşırı bağlama.  Eki-Şub kış penceresi.'
WITH pre AS (
  SELECT marka, ebat, sum(adet) commit_adet, sum(adet*liste_kdvdahil) commit_tl
    FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS'
   GROUP BY 1,2),
w1 AS (  -- geçen kış 2025-10 .. 2026-02
  SELECT marka, ebat, sum(miktar) adet FROM bi_satis_faturalari
   WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
     AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-03-01' GROUP BY 1,2),
w0 AS (  -- önceki kış 2024-10 .. 2025-02
  SELECT marka, ebat, sum(miktar) adet FROM bi_satis_faturalari
   WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
     AND fatura_tarihi >= DATE '2024-10-01' AND fatura_tarihi < DATE '2025-03-01' GROUP BY 1,2)
SELECT p.marka, p.ebat, round(p.commit_adet) commit, round(p.commit_tl/1e6,2) commit_m,
       round(COALESCE(w1.adet,0)) gecen_kis, round(COALESCE(w0.adet,0)) onceki_kis,
       CASE WHEN COALESCE(w1.adet,0)=0 THEN NULL ELSE round((p.commit_adet/w1.adet)::numeric,2) END ratio,
       CASE WHEN COALESCE(w1.adet,0)=0 THEN '⚠ GEÇMİŞTE HİÇ (yeni/riskli)'
            WHEN p.commit_adet/NULLIF(w1.adet,0) >= 2 THEN '⚠⚠ 2x+ AŞIRI'
            WHEN p.commit_adet/NULLIF(w1.adet,0) >= 1.5 THEN '⚠ 1,5x+ fazla'
            WHEN p.commit_adet/NULLIF(w1.adet,0) <= 0.5 THEN '↓ temkinli/eksik olabilir'
            ELSE 'dengeli' END bayrak
  FROM pre p LEFT JOIN w1 ON w1.marka=p.marka AND w1.ebat=p.ebat
             LEFT JOIN w0 ON w0.marka=p.marka AND w0.ebat=p.ebat
 ORDER BY p.commit_tl DESC LIMIT 30;

\echo '################ 3b) ÖZET — taahhüdün ne kadarı aşırı/geçmişsiz (₺ ağırlıklı) ################'
WITH pre AS (SELECT marka, ebat, sum(adet) c, sum(adet*liste_kdvdahil) tl FROM bi_on_siparis
              WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS' GROUP BY 1,2),
w1 AS (SELECT marka, ebat, sum(miktar) a FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
        AND fatura_tarihi>=DATE '2025-10-01' AND fatura_tarihi<DATE '2026-03-01' GROUP BY 1,2)
SELECT round(sum(pre.tl)/1e6,1) toplam_taahhut_m,
       round(sum(pre.tl) FILTER (WHERE COALESCE(w1.a,0)=0)/1e6,1) gecmissiz_m,
       round(sum(pre.tl) FILTER (WHERE w1.a>0 AND pre.c/w1.a>=2)/1e6,1) asiri2x_m,
       round(sum(pre.tl) FILTER (WHERE w1.a>0 AND pre.c/w1.a>=1.5)/1e6,1) fazla15x_m,
       round(100*sum(pre.tl) FILTER (WHERE COALESCE(w1.a,0)=0 OR pre.c/NULLIF(w1.a,0)>=1.5)/NULLIF(sum(pre.tl),0))::int riskli_pct
  FROM pre LEFT JOIN w1 ON w1.marka=pre.marka AND w1.ebat=pre.ebat;
