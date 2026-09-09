-- ============================================================
-- Derive · KORREKSIYON: sebep_arastir_marj ask_why||'literal' -> ::text cast
-- text[] || bare-literal -> Postgres 'anyarray||anyarray' secip literali dizi
-- sanip cokuyordu (malformed array literal). 3 site ::text cast ile duzeltilir.
-- Programatik (canli tanimi al, guard, yeniden yarat). Agnostik-disi ama nabiz+
-- CEO asistan + finans oda hepsi bu fonksiyonu cagiriyor.
-- ============================================================
\pset pager off
DO $mig$
DECLARE d text; a1 text; a2 text; a3 text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='sebep_arastir_marj';
  a1 := 'ask_why||''karışımın neden bozulduğu''';
  a2 := 'ask_why||''maliyet artışının kök nedeni''';
  a3 := 'ask_why||''fiyat düşüşünün nedeni''';
  IF position(a1 IN d)=0 OR position(a2 IN d)=0 OR position(a3 IN d)=0 THEN
    RAISE EXCEPTION 'ANCHOR YOK (a1=% a2=% a3=%)', position(a1 IN d), position(a2 IN d), position(a3 IN d);
  END IF;
  d := replace(d, a1, a1||'::text');
  d := replace(d, a2, a2||'::text');
  d := replace(d, a3, a3||'::text');
  EXECUTE d;
  RAISE NOTICE 'sebep_arastir_marj: 3 ask_why append ::text ile duzeltildi.';
END $mig$;

\echo '=== DOGRULAMA: kalan bare-literal ask_why append (0 olmali) ==='
SELECT count(*) AS bare_kalan
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='sebep_arastir_marj'
  AND pg_get_functiondef(p.oid) ~ 'ask_why\|\|''[^'']+''[^:]';

\echo '=== FONKSIYONEL TEST: KRB marka-marj icgorulerini fiilen uret (cokerse hata verir) ==='
SELECT count(*) AS uretilen
FROM (
  SELECT sebep_arastir_marj('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid, kanit->>'marka') j
  FROM bi_icgoru
  WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid AND bolum='marka-marj'
    AND durum='yeni' AND kanit->>'marka' IS NOT NULL
) q;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SEBEP_MARJ_ARRAYFIX_V1',
       'sebep_arastir_marj: ask_why (text[]) || bare-literal 3 site -> ::text cast (element-append)',
       'text[]||unknown-literal Postgres''te anyarray||anyarray''e cozulup literali dizi sanip cokuyordu (malformed array literal); fiyat/maliyet/mix aciklanamayan-kok dallarinda. nabiz + CEO asistan + finans oda etkileniyordu.',
       '{"fonksiyon":"sebep_arastir_marj","site":3,"belirti":"22P02 malformed array literal","yontem":"programatik replace + guard"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SEBEP_MARJ_ARRAYFIX_V1');

\echo '=== FIX SONU ==='
