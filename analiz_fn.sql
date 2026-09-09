-- vade_makasi() + marka_saglik() — curated ekonomist fonksiyonlari. Dogrulanmis mantik (ekonomi_teshis).
SET lock_timeout = '15s';

-- 1) VADE MAKASI — agirlikli satis vs alim vadesi, 12ay + onceki 12ay + kayma
CREATE OR REPLACE FUNCTION vade_makasi(p_tenant text)
RETURNS TABLE(satis_vade_12 numeric, alim_vade_12 numeric, makas_12 numeric,
              satis_vade_onceki numeric, alim_vade_onceki numeric, makas_onceki numeric, kayma numeric)
LANGUAGE sql STABLE AS $fn$
  WITH sat AS (
    SELECT satir_tutar t,
      CASE WHEN odeme_kosulu ~* 'pe(ş|s)in|nakit|havale|kredi kart|(ç|c)ek|senet|mukabil' THEN 0
           WHEN odeme_kosulu ~ '[0-9]+' THEN (regexp_match(odeme_kosulu,'([0-9]+)'))[1]::int END g,
      fatura_tarihi ft
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-730),
  al AS (
    SELECT satir_kdv_haric t, vade_gun g, fatura_tarihi ft
    FROM bi_tedarikci_faturalari WHERE tenant_id::text=p_tenant AND satir_kdv_haric>0 AND fatura_tarihi>=CURRENT_DATE-730)
  SELECT x.s12, x.a12, round(x.s12-x.a12,1), x.so, x.ao, round(x.so-x.ao,1), round((x.s12-x.a12)-(x.so-x.ao),1)
  FROM (
    SELECT round(sum(s.g*s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft>=CURRENT_DATE-365)/NULLIF(sum(s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft>=CURRENT_DATE-365),0),1) s12,
           round(sum(s.g*s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0),1) so,
           (SELECT round(sum(a.g*a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft>=CURRENT_DATE-365)/NULLIF(sum(a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft>=CURRENT_DATE-365),0),1) FROM al a) a12,
           (SELECT round(sum(a.g*a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0),1) FROM al a) ao
    FROM sat s
  ) x
$fn$;

-- 2) MARKA SAGLIGI — marka basina sizinti + olu stok + gecisgenlik + sorun sayisi (birlestirici)
CREATE OR REPLACE FUNCTION marka_saglik(p_tenant text)
RETURNS TABLE(marka text, brut_kar_m numeric, sizinti_m numeric, olu_stok_m numeric, gecisgenlik_fark int, sorun_say int)
LANGUAGE sql STABLE AS $fn$
  WITH bk AS (SELECT marka, sum(brut_kar) bk, sum(-brut_kar) FILTER (WHERE brut_kar<0) siz
                FROM bi_marj_atom WHERE tenant_id::text=p_tenant AND ay>=CURRENT_DATE-365 GROUP BY 1),
  olu AS (SELECT bsd.marka, sum(bsd.toplam_deger) v FROM bi_stok_durumu bsd
            WHERE bsd.tenant_id::text=p_tenant AND bsd.export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=p_tenant)
              AND bsd.grup_adi ILIKE 'LASTIK%' AND bsd.eldeki_miktar>0
              AND NOT EXISTS (SELECT 1 FROM bi_stok_hareket h WHERE h.tenant_id::text=p_tenant AND h.kalem_kodu=bsd.kalem_kodu AND h.cikis>0 AND h.belge_tarihi>=now()-INTERVAL '90 days')
            GROUP BY 1),
  al AS (SELECT marka, sum(birim_fiyat_kdv_haric*miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365),0) ab,
                sum(birim_fiyat_kdv_haric*miktar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0) ao
           FROM bi_tedarikci_faturalari WHERE tenant_id::text=p_tenant AND miktar>0 AND birim_fiyat_kdv_haric>0 AND marka NOT ILIKE 'DIGER' GROUP BY 1),
  sa AS (SELECT marka, sum(satir_tutar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365),0) sb,
                sum(satir_tutar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0) so
           FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant AND miktar>0 AND satir_tutar>0 AND grup_adi LIKE 'LASTIK%' GROUP BY 1)
  SELECT m, round(COALESCE(bkbk,0)/1e6,1), round(COALESCE(siz,0)/1e6,1), round(COALESCE(ov,0)/1e6,1), gf,
         (CASE WHEN COALESCE(siz,0)>2e5 THEN 1 ELSE 0 END
          + CASE WHEN COALESCE(ov,0)>1e6 THEN 1 ELSE 0 END
          + CASE WHEN gf IS NOT NULL AND gf<=-10 THEN 1 ELSE 0 END)
  FROM (
    SELECT COALESCE(bk.marka, olu.marka) m, bk.bk bkbk, bk.siz siz, olu.v ov,
           CASE WHEN al.ao>0 AND sa.so>0 THEN round(100*(sa.sb/NULLIF(sa.so,0)-1)-100*(al.ab/NULLIF(al.ao,0)-1))::int END gf
      FROM bk FULL JOIN olu ON bk.marka=olu.marka
         LEFT JOIN al ON al.marka=COALESCE(bk.marka,olu.marka)
         LEFT JOIN sa ON sa.marka=COALESCE(bk.marka,olu.marka)
     WHERE COALESCE(bk.bk,0)<>0 OR COALESCE(olu.v,0)>0
  ) z
  ORDER BY (CASE WHEN COALESCE(siz,0)>2e5 THEN 1 ELSE 0 END + CASE WHEN COALESCE(ov,0)>1e6 THEN 1 ELSE 0 END + CASE WHEN gf IS NOT NULL AND gf<=-10 THEN 1 ELSE 0 END) DESC,
           COALESCE(siz,0)+COALESCE(ov,0) DESC
$fn$;

\echo '===== TEST vade_makasi ====='
SELECT * FROM vade_makasi('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa');
\echo '===== TEST marka_saglik (sorun_say>=1, top 15) ====='
SELECT * FROM marka_saglik('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa') WHERE sorun_say>=1 ORDER BY sorun_say DESC, sizinti_m+olu_stok_m DESC LIMIT 15;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ANALIZ_FN_V1',
 'Curated ekonomist fonksiyonlari: vade_makasi(tenant) (satis/alim vadesi + makas + kayma) ve marka_saglik(tenant) (marka basina sizinti + olu stok + gecisgenlik + sorun_say birlestirici). CEO Asistani bunlari cagirir; kanonik dogrulanmis mantik.',
 'onsiparis_kaderi deseninin devami. marka_saglik "Continental uc yerden kaniyor" sentezini tek satirda verir (sorun_say>=2). Asistan elle kurmaz -> tutarli + hizli.',
 '{"fonksiyonlar":["vade_makasi(text)","marka_saglik(text)"],"vade_dogrulandi":"satis 43.1 vs alim 49.7, +7.6->-6.6 kayma","saglik_kolon":"marka,brut_kar_m,sizinti_m,olu_stok_m,gecisgenlik_fark,sorun_say"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ANALIZ_FN_V1');
