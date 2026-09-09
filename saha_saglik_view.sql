-- SAHA_SAGLIK_V1 — kanonik müşteri-sağlık tanımı (TEK KAYNAK).
--   Ritim-duyarlı: müşterinin kendi alım temposuna göre Aktif / Soğuyor / Pasif.
--   Üç yüzey (Kapsam rozeti, Portföy Sağlığı, gerekirse başkaları) bu view'i okur — tek yasa.
--   Anchor = tenant'ın EN SON fatura tarihi (ingest gecikmesinde herkesi bayat göstermez;
--   Saha ROI ile aynı anchor mantığı — Kapsam rozetindeki CURRENT_DATE tutarsızlığını da bu kapatacak).
--   Salt-DDL + read-only dağılım. Uygulamaya DOKUNMAZ.

CREATE OR REPLACE VIEW saha_musteri_saglik AS
WITH anchor AS (
  SELECT tenant_id::text AS tid, MAX(fatura_tarihi)::date AS son
  FROM bi_satis_faturalari
  GROUP BY tenant_id::text
),
aylar AS (  -- son 18 ayda alım OLAN aylar (tek müşteri-ay)
  SELECT f.tenant_id::text AS tid, f.musteri_kodu AS kod,
         date_trunc('month', f.fatura_tarihi)::date AS ay
  FROM bi_satis_faturalari f
  JOIN anchor a ON a.tid = f.tenant_id::text
  WHERE f.musteri_kodu IS NOT NULL
    AND f.fatura_tarihi >= (a.son - INTERVAL '18 months')
  GROUP BY 1, 2, 3
),
ym AS (
  SELECT tid, kod, ay,
         (EXTRACT(YEAR FROM ay)::int * 12 + EXTRACT(MONTH FROM ay)::int) AS ymi
  FROM aylar
),
gaps AS (  -- ardışık aktif aylar arası boşluk (ay)
  SELECT tid, kod, ymi - LAG(ymi) OVER (PARTITION BY tid, kod ORDER BY ymi) AS gap
  FROM ym
),
ritimler AS (  -- ritim = medyan boşluk
  SELECT tid, kod, percentile_cont(0.5) WITHIN GROUP (ORDER BY gap) AS ritim
  FROM gaps WHERE gap IS NOT NULL GROUP BY tid, kod
),
agg AS (
  SELECT tid, kod, COUNT(*) AS n_ay, MAX(ymi) AS son_ymi
  FROM ym GROUP BY tid, kod
),
anc AS (
  SELECT tid, (EXTRACT(YEAR FROM son)::int * 12 + EXTRACT(MONTH FROM son)::int) AS anchor_ymi
  FROM anchor
)
SELECT ag.tid AS tenant_id, ag.kod AS musteri_kodu,
       ag.n_ay,
       r.ritim,
       (an.anchor_ymi - ag.son_ymi) AS recency_ay,
       CASE
         WHEN ag.n_ay < 3 THEN                                   -- ritim belirsiz → sade recency
           CASE WHEN (an.anchor_ymi - ag.son_ymi) <= 3 THEN 'aktif'
                WHEN (an.anchor_ymi - ag.son_ymi) <= 6 THEN 'soguyor'
                ELSE 'pasif' END
         ELSE                                                    -- ritim-duyarlı
           CASE WHEN (an.anchor_ymi - ag.son_ymi) >= 12 THEN 'pasif'                                   -- tavan
                WHEN (an.anchor_ymi - ag.son_ymi) <= COALESCE(r.ritim, 1) + 1 THEN 'aktif'             -- kendi temposunda
                WHEN (an.anchor_ymi - ag.son_ymi) <= GREATEST(2.5 * COALESCE(r.ritim, 1), COALESCE(r.ritim, 1) + 2) THEN 'soguyor'
                ELSE 'pasif' END
       END AS durum,
       CASE WHEN ag.n_ay < 3 THEN 'dusuk' ELSE 'yuksek' END AS guven
FROM agg ag
JOIN anc an ON an.tid = ag.tid
LEFT JOIN ritimler r ON r.tid = ag.tid AND r.kod = ag.kod;

-- ── Fingerprint ────────────────────────────────────────────────────────────
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SAHA_SAGLIK_V1',
 'Kanonik musteri-saglik tanimi: VIEW saha_musteri_saglik (grain tenant_id,musteri_kodu). Ritim-duyarli durum: aktif/soguyor/pasif + guven(yuksek/dusuk). Ritim = son 18 ayda alim olan aylar arasi medyan bosluk; recency = anchor(en son fatura ayi) - son alim ayi. Esikler: aktif<=ritim+1, soguyor<=max(2.5*ritim,ritim+2), pasif ustu veya >=12 ay tavan; <3 alim ayi = ritim belirsiz (sade recency 3/6 ay).',
 'Tek yasa: kayiyor/sadik etiketi uygulamada tek anlama gelsin. Kapsam rozeti + Portfoy Sagligi + (aggregat degil) ayni tanimi okuyacak. Sabit H1/H2 topakli B2B alimda yanlis alarm uretiyordu; ritim-duyarli daha dogru. Anchor=en son fatura (ingest gecikmesi herkesi bayat gostermesin).',
 '{"marker":"SAHA_SAGLIK_V1","nesne":"VIEW saha_musteri_saglik","durumlar":["aktif","soguyor","pasif"],"esik":{"aktif":"<=ritim+1","soguyor":"<=max(2.5*ritim,ritim+2)","pasif":">ust veya >=12ay"},"anchor":"max(fatura_tarihi)","tuketici":["Kapsam rozeti","Portfoy Sagligi"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SAHA_SAGLIK_V1');

INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, kanit, aktif, eklendi_at, guncellendi_at, son_gorulme)
SELECT 'saha_musteri_saglik', 'view',
 'Kanonik musteri-saglik durumu (aktif/soguyor/pasif) — ritim-duyarli churn/yaslanma. Musterinin kendi alim temposuna gore. Saha modulunde kayiyor/sadik etiketinin TEK kaynagi.',
 'VIEW: son 18 ay aktif aylar → medyan bosluk(ritim) + recency(en son fatura ayina gore). aktif<=ritim+1, soguyor<=max(2.5*ritim,ritim+2), pasif ustu/>=12ay. <3 alim = ritim belirsiz(guven=dusuk). JOIN (tenant_id,musteri_kodu).',
 'saha', 'canli', 'taslak',
 '{"marker":"SAHA_SAGLIK_V1","nesne":"VIEW saha_musteri_saglik"}'::jsonb,
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_musteri_saglik');

-- ── DAĞILIM (read-only dry-run) — KRB · eşikleri gözle doğrula ───────────────
\echo '=== DURUM DAGILIMI (aktif saha_musteri) ==='
SELECT COALESCE(s.durum,'alim_yok') AS durum,
       COALESCE(s.guven,'-')        AS guven,
       COUNT(*)                     AS musteri,
       to_char(SUM(COALESCE(c.yil,0)),'FM999G999G999G999') AS ciro_12ay
FROM saha_musteri m
LEFT JOIN saha_musteri_saglik s
  ON s.musteri_kodu = m.musteri_kodu AND s.tenant_id = m.tenant_id::text
LEFT JOIN (SELECT musteri_kodu, SUM(satir_tutar) AS yil
             FROM bi_satis_faturalari
            WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
              AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days')
            GROUP BY musteri_kodu) c ON c.musteri_kodu = m.musteri_kodu
WHERE m.tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND m.aktif=true
GROUP BY 1,2 ORDER BY 1,2;

\echo '=== TIP x DURUM (toptan/filo dagilimi sane mi) ==='
SELECT m.tip,
       COALESCE(s.durum,'alim_yok') AS durum,
       COUNT(*) AS musteri
FROM saha_musteri m
LEFT JOIN saha_musteri_saglik s
  ON s.musteri_kodu = m.musteri_kodu AND s.tenant_id = m.tenant_id::text
WHERE m.tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND m.aktif=true
GROUP BY 1,2 ORDER BY 1,2;

\echo '=== RITIM DAGILIMI (medyan bosluk ay, guven=yuksek olanlar) ==='
SELECT ritim AS ritim_ay, COUNT(*) AS musteri
FROM saha_musteri_saglik
WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND guven='yuksek'
GROUP BY 1 ORDER BY 1;

\echo '=== fingerprint ==='
SELECT 'insa_gunlugu' k, count(*) n FROM bi_insa_gunlugu WHERE adim='SAHA_SAGLIK_V1'
UNION ALL SELECT 'bi_yetenek', count(*) FROM bi_yetenek WHERE ad='saha_musteri_saglik';
