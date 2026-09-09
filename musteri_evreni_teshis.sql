-- MÜŞTERİ EVRENİ teşhis (READ-ONLY) — marj bazı kanonla tutuyor mu + atom-join kapsam kaybı. 12 ay.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '===== 1) MARJ BAZI — müşteri-evreni yöntemi (birim_maliyet) vs kanon (12 ay) ====='
WITH ev AS (
  SELECT sum(f.satir_tutar) ciro,
         sum(f.miktar*a.birim_maliyet) mal,
         sum(f.miktar*COALESCE(a.birim_maliyet_kanon,a.birim_maliyet)) mal_kanon
    FROM bi_satis_faturalari f
    JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date
   WHERE f.tenant_id::text=:'t' AND f.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-INTERVAL '12 months' AND f.satir_tutar>0),
kanon AS (SELECT sum(ciro) ciro, sum(brut_kar) bk FROM bi_marj_atom
           WHERE tenant_id::text=:'t' AND ay>=date_trunc('month',CURRENT_DATE)-INTERVAL '12 months')
SELECT round(ev.ciro/1e6,1) ev_ciro_m,
       round((ev.ciro-ev.mal)/NULLIF(ev.ciro,0)*100,1)        ev_marj_birim_maliyet,
       round((ev.ciro-ev.mal_kanon)/NULLIF(ev.ciro,0)*100,1)  ev_marj_kanon_maliyet,
       round(kanon.ciro/1e6,1) kanon_ciro_m,
       round(kanon.bk/NULLIF(kanon.ciro,0)*100,1)             kanon_marj_atom
  FROM ev, kanon;

\echo '===== 2) ATOM-JOIN KAPSAM — LASTIK satışının ne kadarı atom''a eşleşiyor (düşen = müşteri-evreninde yok) ====='
WITH tot AS (SELECT sum(satir_tutar) ciro, count(*) n FROM bi_satis_faturalari
              WHERE tenant_id::text=:'t' AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-INTERVAL '12 months' AND satir_tutar>0 AND grup_adi LIKE 'LASTIK%'),
mt AS (SELECT sum(f.satir_tutar) ciro, count(*) n FROM bi_satis_faturalari f
        WHERE f.tenant_id::text=:'t' AND f.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-INTERVAL '12 months' AND f.satir_tutar>0 AND f.grup_adi LIKE 'LASTIK%'
          AND EXISTS (SELECT 1 FROM bi_marj_atom a WHERE a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date))
SELECT round(tot.ciro/1e6,1) tum_lastik_ciro_m, tot.n tum_satir,
       round(mt.ciro/1e6,1) eslesen_ciro_m, mt.n eslesen_satir,
       round(100*mt.ciro/NULLIF(tot.ciro,0))::int eslesen_pct,
       round((tot.ciro-mt.ciro)/1e6,1) dusen_m;

\echo '===== 3) birim_maliyet vs birim_maliyet_kanon — satır düzeyinde ne kadar farklı ====='
SELECT count(*) satir,
       round(avg(birim_maliyet),2) ort_birim_maliyet,
       round(avg(birim_maliyet_kanon),2) ort_kanon,
       count(*) FILTER (WHERE birim_maliyet_kanon IS NULL) kanon_null,
       count(*) FILTER (WHERE birim_maliyet_kanon IS NOT NULL AND abs(birim_maliyet-birim_maliyet_kanon)>0.01) farkli_satir
  FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=date_trunc('month',CURRENT_DATE)-INTERVAL '12 months';
