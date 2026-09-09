-- ÖN-SİPARİŞ KADERİ v2 (READ-ONLY) — 3 artefakt düzeltildi: (1) ebat NORMALİZE eşleşme, (2) yalnız KRB-kendi
-- spekülatif risk, (3) adet-bazlı sıralama (₺ NULL bağımsız). Normalize: yük indeksi/boşluk atılır -> çekirdek ebat.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '################ 1) EBAT EŞLEŞME TESTİ — string mi tutmuyor? (artefakt-1 kontrolü) ################'
WITH p AS (SELECT DISTINCT marka, ebat,
              substring(upper(regexp_replace(ebat,'\s','','g')) from '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') nrm
             FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS'),
s_exact AS (SELECT DISTINCT marka, ebat FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND grup_adi LIKE 'LASTIK%'),
s_nrm AS (SELECT DISTINCT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') nrm
            FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND grup_adi LIKE 'LASTIK%')
SELECT count(*) preorder_ebat_say,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM s_exact e WHERE e.marka=p.marka AND e.ebat=p.ebat)) exact_eslesme,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM s_nrm n WHERE n.marka=p.marka AND n.nrm=p.nrm)) normalize_eslesme
  FROM p;

\echo '################ 2) KADER v2 — YALNIZ KRB-kendi, normalize ebat, adet sıralı (top 25) ################'
\echo '    ratio = krb_commit / EN İYİ geçmiş kış (max(gecen,onceki)) — muhafazakar. >1,5 aşırı.'
WITH pre AS (
  SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') nrm,
         sum(adet) commit
    FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS' AND upper(alici)='KRB'
   GROUP BY 1,2),
w AS (
  SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') nrm,
         sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2025-10-01' AND fatura_tarihi<DATE '2026-03-01') w1,
         sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2025-03-01') w0
    FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
     AND fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2026-03-01' GROUP BY 1,2)
SELECT p.marka, p.nrm ebat, round(p.commit) krb_commit,
       round(COALESCE(w.w1,0)) gecen_kis, round(COALESCE(w.w0,0)) onceki_kis,
       CASE WHEN GREATEST(COALESCE(w.w1,0),COALESCE(w.w0,0))=0 THEN NULL
            ELSE round((p.commit/GREATEST(COALESCE(w.w1,0),COALESCE(w.w0,0)))::numeric,2) END ratio_enIyi,
       CASE WHEN GREATEST(COALESCE(w.w1,0),COALESCE(w.w0,0))=0 THEN '⚠ geçmişte hiç'
            WHEN p.commit/GREATEST(COALESCE(w.w1,0),COALESCE(w.w0,0))>=2 THEN '⚠⚠ 2x+'
            WHEN p.commit/GREATEST(COALESCE(w.w1,0),COALESCE(w.w0,0))>=1.5 THEN '⚠ 1,5x+'
            WHEN p.commit/GREATEST(COALESCE(w.w1,0),COALESCE(w.w0,0))<=0.6 THEN '↓ temkinli'
            ELSE 'dengeli' END bayrak
  FROM pre p LEFT JOIN w ON w.marka=p.marka AND w.nrm=p.nrm
 WHERE p.nrm IS NOT NULL
 ORDER BY p.commit DESC LIMIT 25;

\echo '################ 3) ÖZET — KRB-kendi taahhüdün adet-bazlı gerçek riski (normalize eşleşmeyle) ################'
WITH pre AS (
  SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') nrm, sum(adet) commit
    FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS' AND upper(alici)='KRB' GROUP BY 1,2),
w AS (
  SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') nrm,
         GREATEST(COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2025-10-01' AND fatura_tarihi<DATE '2026-03-01'),0),
                  COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2025-03-01'),0)) best
    FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
     AND fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2026-03-01' GROUP BY 1,2)
SELECT round(sum(p.commit)) toplam_krb_adet,
       round(sum(p.commit) FILTER (WHERE COALESCE(w.best,0)=0)) gecmissiz_adet,
       round(sum(p.commit) FILTER (WHERE w.best>0 AND p.commit/w.best>=2)) asiri2x_adet,
       round(sum(p.commit) FILTER (WHERE w.best>0 AND p.commit/w.best>=1.5)) fazla15x_adet,
       round(100*sum(p.commit) FILTER (WHERE COALESCE(w.best,0)=0 OR p.commit/NULLIF(w.best,0)>=1.5)/NULLIF(sum(p.commit),0))::int riskli_pct
  FROM pre p LEFT JOIN w ON w.marka=p.marka AND w.nrm=p.nrm WHERE p.nrm IS NOT NULL;
