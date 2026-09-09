-- onsiparis_kaderi() — curated fonksiyon: kış ön-sipariş taahhüdü vs büyüme-ayarlı geçmiş kış (KRB-kendi).
-- Kanonik g (yalnız Ekim-Şubat, lastik, adet). Asistan tek çağrıyla güvenilir/hızlı çeker; her seferinde aynı tanım.
SET lock_timeout = '15s';

CREATE OR REPLACE FUNCTION onsiparis_kaderi(p_tenant text)
RETURNS TABLE(marka text, ebat text, commit_adet int, demonstre_kis int, buyume_g numeric, beklenen int, fazla_adet int, ratio numeric)
LANGUAGE sql STABLE AS $fn$
  WITH d AS (
    SELECT make_date(extract(year FROM CURRENT_DATE)::int-1,10,1) w1s,
           make_date(extract(year FROM CURRENT_DATE)::int,3,1)   w1e,
           make_date(extract(year FROM CURRENT_DATE)::int-2,10,1) w0s,
           make_date(extract(year FROM CURRENT_DATE)::int-1,3,1) w0e ),
  sez AS (SELECT max(sezon_yili) sy FROM bi_on_siparis WHERE tenant_id::text=p_tenant AND sezon='KIS'),
  g AS (
    SELECT GREATEST(
      sum(miktar) FILTER (WHERE fatura_tarihi>=(SELECT w1s FROM d) AND fatura_tarihi<(SELECT w1e FROM d))::numeric
      / NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi>=(SELECT w0s FROM d) AND fatura_tarihi<(SELECT w0e FROM d)),0), 0.2) gf
    FROM bi_satis_faturalari
    WHERE tenant_id::text=p_tenant AND miktar>0 AND grup_adi LIKE 'LASTIK%'
      AND fatura_tarihi>=(SELECT w0s FROM d) AND fatura_tarihi<(SELECT w1e FROM d) ),
  pre AS (
    SELECT upper(marka) mk, substring(upper(regexp_replace(ebat,'[[:space:]]','','g')) FROM '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') eb, sum(adet) c
    FROM bi_on_siparis
    WHERE tenant_id::text=p_tenant AND sezon='KIS' AND sezon_yili=(SELECT sy FROM sez) AND upper(alici)='KRB'
    GROUP BY 1,2 ),
  w AS (
    SELECT upper(marka) mk, substring(upper(regexp_replace(ebat,'[[:space:]]','','g')) FROM '[0-9]{3}/[0-9]{2}R[0-9]{2}C?') eb,
      GREATEST(COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=(SELECT w1s FROM d) AND fatura_tarihi<(SELECT w1e FROM d)),0),
               COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=(SELECT w0s FROM d) AND fatura_tarihi<(SELECT w0e FROM d)),0)) demo
    FROM bi_satis_faturalari
    WHERE tenant_id::text=p_tenant AND miktar>0 AND grup_adi LIKE 'LASTIK%'
      AND fatura_tarihi>=(SELECT w0s FROM d) AND fatura_tarihi<(SELECT w1e FROM d)
    GROUP BY 1,2 )
  SELECT p.mk, p.eb, round(p.c)::int,
         round(COALESCE(w.demo,0))::int,
         round((SELECT gf FROM g),3),
         round(COALESCE(w.demo,0)*(SELECT gf FROM g))::int,
         GREATEST(round(p.c - COALESCE(w.demo,0)*(SELECT gf FROM g)),0)::int,
         CASE WHEN COALESCE(w.demo,0)*(SELECT gf FROM g) < 1 THEN NULL
              ELSE round((p.c/(COALESCE(w.demo,0)*(SELECT gf FROM g)))::numeric,2) END
  FROM pre p LEFT JOIN w ON w.mk=p.mk AND w.eb=p.eb
  WHERE p.eb IS NOT NULL
  ORDER BY GREATEST(p.c - COALESCE(w.demo,0)*(SELECT gf FROM g),0) DESC
$fn$;

\echo '===== TEST — en çok fazla-bağlanan 15 kalem (KRB-kendi, büyüme-ayarlı) ====='
SELECT marka, ebat, commit_adet, beklenen, fazla_adet, ratio, buyume_g
  FROM onsiparis_kaderi('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa')
 WHERE fazla_adet > 0 ORDER BY fazla_adet DESC LIMIT 15;

\echo '===== ÖZET — toplam KRB taahhüt + fazla + fazla% ====='
SELECT sum(commit_adet) krb_commit, sum(fazla_adet) fazla,
       round(100*sum(fazla_adet)/NULLIF(sum(commit_adet),0))::int fazla_pct, max(buyume_g) g
  FROM onsiparis_kaderi('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ONSIPARIS_KADERI_FN',
 'Curated fonksiyon onsiparis_kaderi(tenant) — kış ön-sipariş taahhüdü (KRB-kendi) vs büyüme-ayarlı geçmiş en iyi kış (Ekim-Şubat, lastik, adet, normalize ebat). CEO Asistani kaderi sorusunda bunu cagirir; her seferinde ayni kanonik g, agentik dongu agir sorgu kurmaz.',
 'Asistan kaderi sorusunu canli cok-CTE sorguyla kurunca durdu/tutarsiz g secti (kendi %3,6 vs rijit %13,5). sebep_arastir_marj deseni: kritik tanimi fonksiyona gom -> guvenilir + tek cagri.',
 '{"fonksiyon":"onsiparis_kaderi(text)","doner":"marka,ebat,commit,beklenen,fazla,ratio,g","g":"yalniz Eki-Sub kis lastik adet YoY","sonraki":"sistem haritasina cagri talimati + vade_makasi()/marka_saglik()"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ONSIPARIS_KADERI_FN');
