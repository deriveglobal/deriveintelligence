-- ============================================================================
-- DERİVE — ORGANİZMA KATMANI CANLI DENETİMİ (reasoning/organism core)
-- 30 Tem 2026. Salt-okunur. 16 Tem foundation DEVIR/INSA'daki organizma çekirdeğinin
-- (sebep-araştırıcı, yasa katmanı, hunter, öğrenme, yetenek defteri, kalp atışı, içgörü)
-- hâlâ CANLI mı yoksa ölü kod mu olduğunu doğrular.
-- tenant = f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
--
-- ÇALIŞTIRMA (Mac'ten):
--   scp -i ~/.ssh/roomsium_hetzner_ed25519 \
--     ~/Desktop/krb-session-outputs/deriveapp/derive_organizma_denetim.sql \
--     root@5.161.234.59:/opt/krb-assessment/
--   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 \
--     'U=$(docker exec krb-assessment-postgres printenv POSTGRES_USER); \
--      D=$(docker exec krb-assessment-postgres printenv POSTGRES_DB); \
--      docker exec -i krb-assessment-postgres psql -U "$U" -d "$D" \
--        < /opt/krb-assessment/derive_organizma_denetim.sql'
--
-- AYRICA HOST tarafı (cron + dosya — DB'de değil), ayrı çalıştır:
--   ssh ... 'crontab -l 2>/dev/null | grep -iE "nabiz|metrik_snapshot|price_monitor"; \
--            ls -la /opt/krb-assessment/nabiz.sh 2>/dev/null; \
--            docker exec krb-assessment grep -cE "/api/bi/icgoru|sebep_arastir|korelasyon_avci|capraz_kontrol" /app/server.mjs'
-- ============================================================================

\pset pager off
\timing off

-- ---------------------------------------------------------------------------
\echo '=== 1) ORGANİZMA FONKSİYONLARI (pg_proc) — LİSTEDE GÖRÜNEN = CANLI, GÖRÜNMEYEN = YOK ==='
-- ---------------------------------------------------------------------------
SELECT proname AS fonksiyon, count(*) AS adet
  FROM pg_proc
  WHERE proname IN (
    'sebep_arastir_marj','sebep_arastir_musteri','capraz_kontrol',
    'korelasyon_avci','avci_sor','ogren_sor','ogren_bilinen',
    'icgoru_uret_finans','icgoru_uret_musteri',
    'metrik_marj_atom_uret','metrik_snapshot_al',
    'yasa_net_pozisyon','yasa_veri_makul','yasa_celiski_odeme','yasa_zararina_hacim')
  GROUP BY proname
  ORDER BY proname;

-- ---------------------------------------------------------------------------
\echo '=== 2) ORGANİZMA TABLOLARI — var mı (true/false), hataya düşmeden ==='
-- ---------------------------------------------------------------------------
SELECT t AS tablo, (to_regclass('public.'||t) IS NOT NULL) AS var
  FROM unnest(ARRAY[
    'bi_yasa','bi_nabiz','bi_nabiz_durum','bi_yetenek','bi_icgoru',
    'bi_sistem_sorusu','bi_etkinlik','bi_ekonomik_parametreler',
    'bi_tedarikci_tesvik','bi_tedarikci_kampanya',
    'bi_maliyet_ay','bi_maliyet_sku','bi_marj_fact','bi_marj_atom',
    'bi_insa_gunlugu'
  ]) AS t
  ORDER BY 1;

-- ---------------------------------------------------------------------------
\echo '=== 3) YASA KATMANI — canlı yasa var mı, durum dağılımı ==='
-- (aday/taslak/onayli/kapali). onayli/taslak varsa katman yaşıyor.
-- ---------------------------------------------------------------------------
SELECT durum, count(*) AS adet FROM bi_yasa GROUP BY durum ORDER BY 2 DESC;

-- ---------------------------------------------------------------------------
\echo '=== 4) KALP ATIŞI (bi_nabiz) — önce kolonları gör (tarih kolonu hangisi?) ==='
-- ---------------------------------------------------------------------------
SELECT column_name FROM information_schema.columns
  WHERE table_name='bi_nabiz' ORDER BY ordinal_position;
SELECT count(*) AS nabiz_satir FROM bi_nabiz;

-- ---------------------------------------------------------------------------
\echo '=== 5) ÖĞRENME DÖNGÜSÜ + YETENEK DEFTERİ + İÇGÖRÜ — canlılık ==='
-- ---------------------------------------------------------------------------
SELECT count(*) AS sistem_sorusu FROM bi_sistem_sorusu;
SELECT count(*) AS yetenek_kaydi FROM bi_yetenek;
SELECT count(*) AS icgoru_satir  FROM bi_icgoru WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';
SELECT column_name FROM information_schema.columns
  WHERE table_name='bi_icgoru' ORDER BY ordinal_position;

-- ---------------------------------------------------------------------------
\echo '=== 6) MALİYET BAZI (omurga_64 kanonu) — marj atomu canlı, şirket marjı ~%10,4 mü? ==='
-- ---------------------------------------------------------------------------
SELECT
  count(*) AS atom_satir,
  max(ay)  AS son_ay,
  ROUND(100*SUM(brut_kar)/NULLIF(SUM(ciro),0),1) AS sirket_marj_pct
  FROM bi_marj_atom
  WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

-- ---------------------------------------------------------------------------
\echo '=== 7) İNŞA GÜNLÜĞÜ — son 12 deploy adımı (DB ikizi güncel mi?) ==='
-- ---------------------------------------------------------------------------
SELECT adim, ts::date AS tarih FROM bi_insa_gunlugu ORDER BY ts DESC LIMIT 12;

\echo '=== ORGANİZMA DENETİMİ BİTTİ — foundation DEVIR/INSA ile karşılaştır: hangi parça canlı, hangisi ölü ==='
