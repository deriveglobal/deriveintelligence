-- RAPOR_KANON_V1 — saha_musteri_kanon: tüm saha raporları için TEK kanonik müşteri kaydı.
--   "ziyaret / kapsam / tip / ciro" tek tanım (bkz. derive-rapor-kanon.md 6 kural). SALT-DDL, salt-oku view.
--   Kaynak: saha_musteri (aktif) + bi_satis_faturalari (12ay rolling) + saha_ziyaret (TAMAMLANDI) + saha_musteri_saglik.
--   GÜVENLİ: hiçbir rapor henüz okumaz → oluşturmak canlıyı değiştirmez. Önce doğrula, sonra R2b'de raporlar taşınır.
-- KULLANIM (Fatih): docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < saha_kanon_view.sql

\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW saha_musteri_kanon AS
SELECT
  m.tenant_id,
  m.id                                    AS musteri_id,
  m.musteri_kodu,
  m.firma, m.il, m.ilce,
  m.tip                                   AS tip,          -- KANON segment (SAP toptan/filo) — z.tip DEĞİL
  to_jsonb(m)->>'segment'                 AS segment,
  m.sorumlu_rep,
  (m.musteri_kodu IS NOT NULL)            AS matched,      -- ERP eşleşme
  COALESCE(c.ciro_12ay, 0)::numeric       AS ciro_12ay,    -- rolling 365g, musteri_kodu ile
  COALESCE(v.ziyaret_12ay, 0)::int        AS ziyaret_12ay, -- TAMAMLANDI son 365g
  v.son_ziyaret,                                            -- all-time max ziyaret_tarihi (TAMAMLANDI)
  CASE WHEN v.son_ziyaret IS NOT NULL THEN (CURRENT_DATE - v.son_ziyaret) END AS son_ziyaret_gun,
  sg.durum                                AS saglik,        -- kanon sağlık (SAHA_SAGLIK_V1)
  sg.guven                                AS saglik_guven
FROM saha_musteri m
LEFT JOIN LATERAL (
  SELECT SUM(f.satir_tutar) AS ciro_12ay
    FROM bi_satis_faturalari f
   WHERE f.tenant_id::text = m.tenant_id::text
     AND f.musteri_kodu = m.musteri_kodu
     AND f.fatura_tarihi >= CURRENT_DATE - INTERVAL '365 days'
) c ON m.musteri_kodu IS NOT NULL
LEFT JOIN LATERAL (
  SELECT COUNT(*) FILTER (WHERE z.ziyaret_tarihi >= CURRENT_DATE - INTERVAL '365 days') AS ziyaret_12ay,
         MAX(z.ziyaret_tarihi) AS son_ziyaret
    FROM saha_ziyaret z
   WHERE z.tenant_id::text = m.tenant_id::text
     AND z.musteri_id = m.id
     AND z.durum = 'TAMAMLANDI'
) v ON true
LEFT JOIN saha_musteri_saglik sg
  ON sg.tenant_id::text = m.tenant_id::text
 AND sg.musteri_kodu = m.musteri_kodu
WHERE m.aktif = true;

-- ── DOĞRULAMA (KRB tenant) — sayılar mantıklı mı? ──
\echo '== toplam / eşleşen / 12ay-ziyaretli / 12ay-ciro-toplam (DISTINCT kodu) =='
SELECT count(*)                                              AS aktif_musteri,
       count(*) FILTER (WHERE matched)                      AS eslesen,
       count(*) FILTER (WHERE ziyaret_12ay > 0)             AS ziyaretli_12ay,
       count(*) FILTER (WHERE saglik IS NOT NULL)           AS saglikli_kayit,
       round(COALESCE((SELECT SUM(ciro_12ay) FROM (SELECT DISTINCT ON (musteri_kodu) musteri_kodu, ciro_12ay
                        FROM saha_musteri_kanon WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND musteri_kodu IS NOT NULL) q),0)) AS ciro_12ay_distinct
  FROM saha_musteri_kanon
 WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

\echo '== tip (segment) dağılımı =='
SELECT COALESCE(tip,'(boş)') tip, count(*) musteri,
       count(*) FILTER (WHERE matched) eslesen,
       round(sum(ciro_12ay)) ciro_12ay
  FROM saha_musteri_kanon
 WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
 GROUP BY tip ORDER BY musteri DESC;

\echo '== sağlık dağılımı =='
SELECT COALESCE(saglik,'(alım_yok/kayıtsız)') saglik, count(*)
  FROM saha_musteri_kanon
 WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
 GROUP BY saglik ORDER BY 2 DESC;

-- ── FINGERPRINT ──
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'RAPOR_KANON_V1',
 'saha_musteri_kanon view (Faz R2a): tum saha raporlari icin TEK kanonik musteri kaydi — tip(kanon segment)/matched/ciro_12ay/ziyaret_12ay/son_ziyaret/saglik. 6 kanon kurali (derive-rapor-kanon.md): tamamlanmis ziyaret=TAMAMLANDI+ziyaret_tarihi; segment=m.tip (z.tip degil); aktif portfoy paydasi; kapsam=iki adli metrik; 12ay ciro=365g kodu; ciro toplarken kodu dedup. Salt-DDL/salt-oku; henuz rapor okumaz. R2b migrasyonlari raporlari buna tasiyacak.',
 'derive-rapor-denetim.md kok sorun: ziyaret/kapsam/tip sekmeden sekmeye farkli hesaplaniyor. Dunya-standardi = tek kanonik tanim, tum raporlar okur (SAHA_SAGLIK_V1 deseni).',
 '{"marker":"RAPOR_KANON_V1","tur":"view","view":"saha_musteri_kanon","sozlesme":"derive-rapor-kanon.md","faz":"R2a"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='RAPOR_KANON_V1');

INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, aktif)
SELECT 'saha_musteri_kanon', 'tablo',
 'Tum saha raporlari icin tek kanonik aktif-musteri kaydi: tip(segment)/matched/ciro_12ay/ziyaret_12ay/son_ziyaret/saglik. Sekmeler-arasi ziyaret/kapsam/tip tutarsizligini kokten cozer.',
 'VIEW: saha_musteri (aktif) + bi_satis_faturalari (365g rolling, kodu) + saha_ziyaret (TAMAMLANDI) + saha_musteri_saglik. 6 kanon kurali derive-rapor-kanon.md.',
 'saha', 'canli', 'yuksek', true
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_musteri_kanon');

\echo '== fingerprint =='
SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='RAPOR_KANON_V1') insa,
       (SELECT count(*) FROM bi_yetenek WHERE ad='saha_musteri_kanon') yetenek;
