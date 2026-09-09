-- KRB TENANT HARDCODE SÜPÜRME (READ-ONLY) — Faz A hardcode_kalan kontrolünün uygulama-geneli hali.
-- Her VIEW + FONKSIYON tanımını KRB tenant literaline karşı tarar. Beklenen: 0 satır (temiz).
-- Çıkan her satır = o view/fonksiyon KRB'ye gömülü → çok-tenant'ta yanlış/sızıntı.
\set krb 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '===== 1) VIEW + FONKSIYON tanimlarinda gomulu KRB tenant literali (0 satir beklenir) ====='
SELECT 'VIEW' AS tur, schemaname||'.'||viewname AS nesne
  FROM pg_views
 WHERE schemaname='public' AND definition LIKE '%'||:'krb'||'%'
UNION ALL
SELECT 'FUNCTION', n.nspname||'.'||p.proname
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND pg_get_functiondef(p.oid) LIKE '%'||:'krb'||'%'
ORDER BY 1,2;

\echo '===== 2) Finansal kanon view''lari — tenant_id kolonu VAR mi? (hepsinde t olmali = per-tenant) ====='
SELECT c.relname AS view,
       bool_or(a.attname='tenant_id') AS tenant_id_kolonu_var
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
  JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
 WHERE c.relkind='v'
   AND c.relname IN ('v_finans_ticari_sermaye','v_net_gecikmis_musteri','v_stok_deger_kanon','v_marj_cari_ay')
 GROUP BY c.relname ORDER BY c.relname;

\echo '===== 3) Sunucu kodu grep''i (ayri calistir): docker exec krb-assessment grep -n f8a5d20f... /app/server.mjs ====='
\echo '   (Beklenen: yalnizca 2 AI-prompt satiri — dashboard sorgusu DEGIL.)'
