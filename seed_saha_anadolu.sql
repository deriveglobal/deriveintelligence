-- ============================================================
-- Derive · ANADOLU SAHA DATA SEED (idempotent, WHERE NOT EXISTS)
-- Kaynak: bi_satis_faturalari (ERP) + rep_kimlik_koprusu (6 rep uuid).
-- Kurar: saha_musteri (48) + sap_musteri_sahiplik + saha_ziyaret (gecmis)
--        + saha_satis_skor (portfoy proxy). YAPI DEGISMEZ; yalniz Anadolu verisi.
-- Rep eslesme: musteri basina EN COK cirolu satis_temsilcisi -> o rep.
-- ============================================================
\pset pager off
SELECT id AS aid FROM platform_tenants WHERE name ILIKE '%anadolu%' LIMIT 1; \gset
\echo '>>> ANADOLU =' :'aid'

BEGIN;

-- === Ortak kaynak: musteri -> dominant rep + firma/il/kanal/ciro ===
CREATE TEMP TABLE _src ON COMMIT DROP AS
WITH sat AS (
  SELECT musteri_kodu,
         nullif(trim(max(musteri_adi)),'')            AS firma,
         nullif(trim(max(sehir)),'')                  AS il,
         satis_temsilcisi,
         sum(satir_tutar)                             AS ciro,
         max(fatura_tarihi)                           AS son_fatura,
         min(fatura_tarihi)                           AS ilk_fatura,
         count(*)                                     AS satir,
         count(DISTINCT date_trunc('month',fatura_tarihi)) AS ay_say,
         mode() WITHIN GROUP (ORDER BY satis_kanali)  AS kanal,
         mode() WITHIN GROUP (ORDER BY kategori)      AS kategori
    FROM bi_satis_faturalari
   WHERE tenant_id::text=:'aid' AND coalesce(musteri_kodu,'')<>'' AND coalesce(satis_temsilcisi,'')<>''
   GROUP BY musteri_kodu, satis_temsilcisi
),
rank AS (
  SELECT *, row_number() OVER (PARTITION BY musteri_kodu ORDER BY ciro DESC) rn,
            sum(ciro) OVER (PARTITION BY musteri_kodu) ciro_top
    FROM sat
),
dom AS (  -- musteri basina tek satir: dominant rep + toplulastirilmis metrikler
  SELECT r.musteri_kodu,
         max(r.firma)  FILTER (WHERE rn=1) firma,
         max(r.il)     FILTER (WHERE rn=1) il,
         max(r.satis_temsilcisi) FILTER (WHERE rn=1) sap,
         max(r.kanal)  FILTER (WHERE rn=1) kanal,
         max(r.kategori) FILTER (WHERE rn=1) kategori,
         max(r.ciro_top) ciro_12ay,
         max(r.son_fatura) son_fatura,
         min(r.ilk_fatura) ilk_fatura,
         sum(r.satir) satir, max(r.ay_say) ay_say
    FROM rank r GROUP BY r.musteri_kodu
)
SELECT d.*,
       k.user_id AS rep_uuid,
       CASE WHEN coalesce(d.kanal,'') ~* 'PERAKENDE|E-?TICARET|TUKETICI|TÜKETICI' THEN 'TUKETICI' ELSE 'TICARI' END AS tip,
       greatest(0, (CURRENT_DATE - d.son_fatura))::int AS son_gun,
       greatest(1, round(365.0 / NULLIF(d.ay_say,0))::int) AS medyan_gun
  FROM dom d
  LEFT JOIN rep_kimlik_koprusu k ON k.tenant_id::text=:'aid' AND k.sap_temsilci=d.sap AND k.durum='saha';

\echo '--- kaynak musteri sayisi + rep eslesen ---'
SELECT count(*) musteri, count(rep_uuid) rep_eslesen FROM _src;

-- === 1) saha_musteri (idempotent) ===
INSERT INTO saha_musteri (id, tenant_id, tip, firma, musteri_kodu, il, segment, durum, aktif, sorumlu_rep, kayit_kaynagi, created_at, updated_at)
SELECT gen_random_uuid(), :'aid'::uuid, s.tip, coalesce(s.firma, s.musteri_kodu), s.musteri_kodu, s.il,
       NULL, 'AKTIF_MUSTERI', true, s.rep_uuid, 'EXCEL_IMPORT_KONTROL', now(), now()
  FROM _src s
 WHERE NOT EXISTS (SELECT 1 FROM saha_musteri m WHERE m.tenant_id::text=:'aid' AND m.musteri_kodu=s.musteri_kodu);

-- === 2) sap_musteri_sahiplik (idempotent) ===
INSERT INTO sap_musteri_sahiplik (tenant_id, musteri_kodu, ana_sorumlu_user_id, ana_sorumlu_sap, skor, ciro_pay, ay_pay, saha_rep_say, toplam_ciro_12ay, hesaplandi_at)
SELECT :'aid'::uuid, s.musteri_kodu, s.rep_uuid, s.sap,
       round(least(100, greatest(1, 100 - s.son_gun))::numeric,0), 1.0, 1.0, 1, round(s.ciro_12ay), now()
  FROM _src s
 WHERE NOT EXISTS (SELECT 1 FROM sap_musteri_sahiplik p WHERE p.tenant_id::text=:'aid' AND p.musteri_kodu=s.musteri_kodu);

-- === 3) saha_satis_skor (portfoy proxy: recency/frequency -> p_alive/exp30/segment) ===
INSERT INTO saha_satis_skor (tenant_id, musteri_kodu, segment, p_alive, exp30, siparis, son_gun, medyan_gun, hesaplandi_at)
SELECT :'aid'::uuid, s.musteri_kodu,
       CASE WHEN s.son_gun<=45 AND s.ay_say>=8 THEN 'Şampiyon'
            WHEN s.son_gun<=90 THEN 'Sadık'
            WHEN s.son_gun<=180 THEN 'Riskli'
            ELSE 'Uykuda' END,
       round(greatest(0.05, least(0.98, 1.0 - s.son_gun::numeric/365))::numeric,2),
       round(greatest(0, s.ay_say::numeric/12)::numeric,2),
       s.ay_say, s.son_gun, s.medyan_gun, now()
  FROM _src s
 WHERE NOT EXISTS (SELECT 1 FROM saha_satis_skor z WHERE z.tenant_id::text=:'aid' AND z.musteri_kodu=s.musteri_kodu);

-- === 4) saha_ziyaret gecmisi (musteri basina 3 ziyaret, son ~6 ay; idempotent) ===
INSERT INTO saha_ziyaret (id, tenant_id, musteri_id, rep_id, rep_adi, tip, durum, ziyaret_tarihi, katilimci, notlar, detay, kaynak, created_at, updated_at)
SELECT gen_random_uuid(), :'aid'::uuid, m.id, m.sorumlu_rep,
       (SELECT sap_temsilci FROM rep_kimlik_koprusu k WHERE k.tenant_id::text=:'aid' AND k.user_id=m.sorumlu_rep LIMIT 1),
       m.tip, 'TAMAMLANDI',
       (CURRENT_DATE - ((g-1)*45 + (abs(hashtext(m.musteri_kodu)) % 25)))::date,
       'Satın alma sorumlusu',
       (ARRAY[
         'Rutin ziyaret; stok durumu ve sezon kampanyası konuşuldu.',
         'Yeni sezon lastik talebi alındı, teklif hazırlanacak.',
         'Tahsilat hatırlatması yapıldı, ödeme planı netleşti.',
         'Rakip fiyatları soruldu; müşteri karşılaştırma istedi.',
         'Filo yenileme planı görüşüldü, ön mutabakat sağlandı.',
         'Raf ve vitrin düzeni kontrol edildi, bayi memnun.'
       ])[1 + ((abs(hashtext(m.musteri_kodu)) + g) % 6)],
       jsonb_build_object('seed','anadolu_demo','tur','rutin'),
       'EXCEL_MIGRASYON', now(), now()
  FROM saha_musteri m
  CROSS JOIN generate_series(1,3) g
 WHERE m.tenant_id::text=:'aid' AND m.sorumlu_rep IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM saha_ziyaret z WHERE z.tenant_id::text=:'aid' AND z.musteri_id=m.id AND z.detay->>'seed'='anadolu_demo');

COMMIT;

-- === DOGRULAMA ===
\echo ''
\echo '=== SEED SONUC (Anadolu) ==='
SELECT 'saha_musteri' t, count(*) n FROM saha_musteri WHERE tenant_id::text=:'aid'
UNION ALL SELECT 'sap_musteri_sahiplik', count(*) FROM sap_musteri_sahiplik WHERE tenant_id::text=:'aid'
UNION ALL SELECT 'saha_satis_skor', count(*) FROM saha_satis_skor WHERE tenant_id::text=:'aid'
UNION ALL SELECT 'saha_ziyaret', count(*) FROM saha_ziyaret WHERE tenant_id::text=:'aid'
ORDER BY 1;

\echo '--- rep basina musteri + ziyaret dagilimi ---'
SELECT k.sap_temsilci rep,
       count(DISTINCT m.id) musteri,
       (SELECT count(*) FROM saha_ziyaret z WHERE z.tenant_id::text=:'aid' AND z.rep_id=k.user_id) ziyaret
  FROM rep_kimlik_koprusu k
  LEFT JOIN saha_musteri m ON m.tenant_id::text=:'aid' AND m.sorumlu_rep=k.user_id
 WHERE k.tenant_id::text=:'aid' AND k.durum='saha'
 GROUP BY k.sap_temsilci, k.user_id ORDER BY musteri DESC;

\echo '--- IZOLASYON: KRB saha_musteri bozulmadi mi (1687 beklenir) ---'
SELECT 'KRB saha_musteri' t, count(*) FROM saha_musteri WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

\echo '=== SEED SONU ==='
