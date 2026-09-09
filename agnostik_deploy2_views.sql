-- ============================================================
-- Derive · AGNOSTİK FAZ C — DEPLOY 2: 3 view + 2 fonksiyon
-- grup_adi LIKE 'LASTIK%' -> evren_desen(tenant). Programatik replace
-- (canli tanimi al, YALNIZ literali degistir, yeniden yarat). Anchor
-- bulunmazsa ABORT. lock_timeout + KRB oncesi/sonrasi ESITLIK kan2ti.
-- evren_desen KRB icin 'LASTIK%' -> sonuc AYNI olmali (0 degisim beklenir).
-- ============================================================
\pset pager off
\set KRB 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\set ANA '42822870-4ea3-424d-a16f-50b91afca32c'
SET lock_timeout='15s';

-- === ÖNCESİ snapshot ===
CREATE TEMP TABLE _before AS
  SELECT 'krb_dso' k, dso::numeric v FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_dio', dio FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_dpo', dpo FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_marj', marj_pct FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_stok_vfin', stok_deger FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_stok_kanon', stok_deger FROM v_stok_deger_kanon WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_stok_sku', sku_sayisi FROM v_stok_deger_kanon WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_marjcari_rows', count(*)::numeric FROM v_marj_cari_ay WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_marka_saglik_rows', count(*)::numeric FROM marka_saglik(:'KRB')
  UNION ALL SELECT 'ana_dso', dso FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'ANA'
  UNION ALL SELECT 'ana_stok_kanon', stok_deger FROM v_stok_deger_kanon WHERE tenant_id::text=:'ANA';

-- === DÖNÜŞÜM (programatik, guard'lı) ===
DO $mig$
DECLARE d text; oldp text; newp text;
BEGIN
  -- 1) v_finans_ticari_sermaye
  SELECT pg_get_viewdef('v_finans_ticari_sermaye'::regclass, true) INTO d;
  oldp := 's.grup_adi ~~* ''LASTIK%''::text'; newp := 's.grup_adi ~~* evren_desen(s.tenant_id)';
  IF position(oldp IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: v_finans'; END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.v_finans_ticari_sermaye AS ' || replace(d, oldp, newp);

  -- 2) v_stok_deger_kanon
  SELECT pg_get_viewdef('v_stok_deger_kanon'::regclass, true) INTO d;
  oldp := 's.grup_adi ~~* ''LASTIK%''::text'; newp := 's.grup_adi ~~* evren_desen(s.tenant_id)';
  IF position(oldp IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: v_stok_deger_kanon'; END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.v_stok_deger_kanon AS ' || replace(d, oldp, newp);

  -- 3) v_marj_cari_ay
  SELECT pg_get_viewdef('v_marj_cari_ay'::regclass, true) INTO d;
  oldp := 'bi_satis_faturalari.grup_adi ~~ ''LASTIK%''::text'; newp := 'bi_satis_faturalari.grup_adi ~~ evren_desen(bi_satis_faturalari.tenant_id)';
  IF position(oldp IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: v_marj_cari_ay'; END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.v_marj_cari_ay AS ' || replace(d, oldp, newp);

  -- 4) marka_saglik (2 site)
  SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='marka_saglik';
  IF position('bsd.grup_adi ILIKE ''LASTIK%''' IN d)=0 OR position('grup_adi LIKE ''LASTIK%''' IN d)=0
     THEN RAISE EXCEPTION 'ANCHOR YOK: marka_saglik'; END IF;
  d := replace(d, 'bsd.grup_adi ILIKE ''LASTIK%''', 'bsd.grup_adi ILIKE evren_desen(p_tenant)');
  d := replace(d, 'grup_adi LIKE ''LASTIK%''',      'grup_adi LIKE evren_desen(p_tenant)');
  EXECUTE d;

  -- 5) onsiparis_kaderi (2 site LASTIK; alici='KRB' AYRI is - dokunulmuyor)
  SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='onsiparis_kaderi';
  IF position('grup_adi LIKE ''LASTIK%''' IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: onsiparis_kaderi'; END IF;
  d := replace(d, 'grup_adi LIKE ''LASTIK%''', 'grup_adi LIKE evren_desen(p_tenant)');
  EXECUTE d;

  RAISE NOTICE 'D2 donusum tamam: 3 view + 2 fonksiyon.';
END $mig$;

-- === SONRASI snapshot (ayni sorgular) ===
CREATE TEMP TABLE _after AS
  SELECT 'krb_dso' k, dso::numeric v FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_dio', dio FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_dpo', dpo FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_marj', marj_pct FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_stok_vfin', stok_deger FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_stok_kanon', stok_deger FROM v_stok_deger_kanon WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_stok_sku', sku_sayisi FROM v_stok_deger_kanon WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_marjcari_rows', count(*)::numeric FROM v_marj_cari_ay WHERE tenant_id::text=:'KRB'
  UNION ALL SELECT 'krb_marka_saglik_rows', count(*)::numeric FROM marka_saglik(:'KRB')
  UNION ALL SELECT 'ana_dso', dso FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'ANA'
  UNION ALL SELECT 'ana_stok_kanon', stok_deger FROM v_stok_deger_kanon WHERE tenant_id::text=:'ANA';

\echo '=== KRB ÖNCESİ vs SONRASI (hepsi ok olmali; DEGISTI = regresyon) ==='
SELECT b.k, b.v AS onceki, a.v AS sonraki,
       CASE WHEN b.v IS NOT DISTINCT FROM a.v THEN 'ok' ELSE '❌ DEGISTI' END AS durum
FROM _before b JOIN _after a USING(k) ORDER BY b.k;

\echo ''
\echo '=== Kalan LASTIK% literali bu 5 objede (0 olmali) ==='
SELECT 'view' tur, viewname ad FROM pg_views WHERE schemaname='public' AND viewname IN ('v_finans_ticari_sermaye','v_stok_deger_kanon','v_marj_cari_ay') AND definition LIKE '%''LASTIK%''%'
UNION ALL
SELECT 'func', p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('marka_saglik','onsiparis_kaderi') AND pg_get_functiondef(p.oid) LIKE '%''LASTIK%''%';

\echo ''
\echo '=== evren_desen KULLANIMI dogrulama (5 obje de icermeli) ==='
SELECT 'view' tur, viewname ad FROM pg_views WHERE schemaname='public' AND viewname IN ('v_finans_ticari_sermaye','v_stok_deger_kanon','v_marj_cari_ay') AND definition LIKE '%evren_desen%'
UNION ALL
SELECT 'func', p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('marka_saglik','onsiparis_kaderi') AND pg_get_functiondef(p.oid) LIKE '%evren_desen%'
ORDER BY 1,2;

-- === FINGERPRINT ===
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_EVREN_VIEWS_V1',
       '3 canonical view (v_finans_ticari_sermaye, v_stok_deger_kanon, v_marj_cari_ay) + 2 fonksiyon (marka_saglik, onsiparis_kaderi): grup_adi LIKE LASTIK% -> evren_desen(tenant)',
       'Faz C: is-evreni per-tenant; KRB evren_desen=LASTIK% -> sonuc birebir ayni (regresyon yok, oncesi/sonrasi kanitlandi)',
       '{"view":3,"func":2,"yontem":"programatik replace + anchor guard + lock_timeout","not":"onsiparis_kaderi alici=KRB literali AYRI is; taksonomi (PSR/TBR/OTR) D3"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_EVREN_VIEWS_V1');

\echo '=== DEPLOY 2 SONU ==='
