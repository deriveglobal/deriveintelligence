-- ============================================================
-- Derive · ANADOLU KOKPİT QA PROBE (SALT-OKUNUR)
-- Her kokpit/finans yuzeyinin ARKA-VERISI Anadolu icin doluyor mu +
-- TENANT-IZOLE mi (yanlislikla KRB satiri sizmiyor) + kimlik agnostik mi.
-- PASS/FAIL basar. Hicbir sey yazmaz.
-- ============================================================
\pset pager off
SELECT id AS aid, name AS anm FROM platform_tenants WHERE name ILIKE '%anadolu%' LIMIT 1;
\gset

\echo ''
\echo '=================== ANADOLU KOKPIT QA ==================='
\echo '>>> tenant:' :'anm' '(' :'aid' ')'
\echo ''

WITH probe(surface, n, detay) AS (
  -- KIMLIK (agnostik AI prompt bunu okur)
  SELECT 'KIMLIK/tenant_adi', (SELECT count(*) FROM platform_tenants WHERE id::text=:'aid' AND coalesce(name,'')<>''),
         (SELECT name FROM platform_tenants WHERE id::text=:'aid')
  -- KOKPIT ciro (bi_metrik_gecmis: ciro_lastik + ciro_tum)
  UNION ALL SELECT 'KOKPIT/ciro (metrik)', (SELECT count(*) FROM bi_metrik_gecmis WHERE tenant_id::text=:'aid' AND metrik IN ('ciro_lastik','ciro_tum')),
         (SELECT to_char(max(deger),'FM999G999G999') FROM bi_metrik_gecmis WHERE tenant_id::text=:'aid' AND metrik='ciro_lastik')
  -- KANONIK MARJ (bi_marj_atom)
  UNION ALL SELECT 'KOKPIT/marj (atom)', (SELECT count(*) FROM bi_marj_atom WHERE tenant_id::text=:'aid'),
         (SELECT round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1)::text||'%' FROM bi_marj_atom WHERE tenant_id::text=:'aid')
  -- DONGU/DSO (v_finans_ticari_sermaye)
  UNION ALL SELECT 'FINANS/dongu (v_finans)', (SELECT count(*) FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'aid'),
         (SELECT 'DSO='||round(dso)||' DIO='||round(dio)||' DPO='||round(dpo)||' CCC='||round(ccc) FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'aid')
  -- NET GECIKMIS (v_net_gecikmis_musteri)
  UNION ALL SELECT 'FINANS/net gecikmis', (SELECT count(*) FROM v_net_gecikmis_musteri WHERE tenant_id::text=:'aid'),
         (SELECT to_char(sum(net_gecikmis),'FM999G999G999') FROM v_net_gecikmis_musteri WHERE tenant_id::text=:'aid')
  -- TAHSILAT (bi_tahsilat)
  UNION ALL SELECT 'FINANS/tahsilat', (SELECT count(*) FROM bi_tahsilat WHERE tenant_id::text=:'aid'), ''
  -- STOK DEGER (bi_metrik_gecmis stok_deger)
  UNION ALL SELECT 'FINANS/stok deger', (SELECT count(*) FROM bi_metrik_gecmis WHERE tenant_id::text=:'aid' AND metrik='stok_deger'),
         (SELECT to_char(max(deger),'FM999G999G999') FROM bi_metrik_gecmis WHERE tenant_id::text=:'aid' AND metrik='stok_deger')
  -- MUSTERI RISK / alacak (bi_musteri_risk)
  UNION ALL SELECT 'FINANS/musteri risk', (SELECT count(*) FROM bi_musteri_risk WHERE tenant_id::text=:'aid' AND coalesce(musteri_mi,true)), ''
  -- MARJ FACT kirilim (bi_marj_fact)
  UNION ALL SELECT 'KOKPIT/marka kirilim (marj_fact)', (SELECT count(*) FROM bi_marj_fact WHERE tenant_id::text=:'aid'), ''
)
SELECT CASE WHEN n>0 THEN '✅ PASS' ELSE '❌ FAIL' END AS sonuc, surface, n AS satir, detay
FROM probe ORDER BY (n>0), surface;

\echo ''
\echo '=== IZOLASYON: bu yuzeylerde YANLIS tenant sizmasi var mi? (KRB Anadolu sorgusunda gorunmemeli) ==='
\echo '(Asagidaki sorgular Anadolu filtreli; KRB satir sayisi AYRI referans — karismamali)'
SELECT 'bi_marj_atom' t, count(*) FILTER (WHERE tenant_id::text=:'aid') anadolu, count(*) FILTER (WHERE tenant_id::text<>:'aid') diger FROM bi_marj_atom
UNION ALL SELECT 'bi_marj_fact', count(*) FILTER (WHERE tenant_id::text=:'aid'), count(*) FILTER (WHERE tenant_id::text<>:'aid') FROM bi_marj_fact
UNION ALL SELECT 'bi_metrik_gecmis', count(*) FILTER (WHERE tenant_id::text=:'aid'), count(*) FILTER (WHERE tenant_id::text<>:'aid') FROM bi_metrik_gecmis
ORDER BY 1;

\echo ''
\echo '=== KANIT: her metrigin tenant kirilimi (iki tenant da bagimsiz durmali) ==='
SELECT metrik, count(*) FILTER (WHERE tenant_id::text=:'aid') anadolu, count(*) FILTER (WHERE tenant_id::text<>:'aid') krb
FROM bi_metrik_gecmis WHERE metrik IN ('dso','ciro_lastik','ciro_tum','stok_deger','alacak','tedarikci_borcu','net_isletme_sermayesi')
GROUP BY metrik ORDER BY metrik;

\echo ''
\echo '=== QA SONU (yazma yok) ==='
