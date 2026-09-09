#!/usr/bin/env bash
# DEPLOY omurga_71 — §6.5 boyut (B): ciro_lastik x SEGMENT + x SEZON omurgaya. DB-only, rebuild YOK.
# Fatih karari: YENILEME (kaplama) ve TAMIR AYRI segment. Kaynak: bi_marj_atom.kategori -> normalize fonksiyonlari.
# Turkce I tuzagi: LIKE (case-sensitive, veri buyuk harf) kullanildi, ILIKE DEGIL.
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform"
PSQLI="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. BAZ — ciro_lastik su an hangi boyutlarda"
$PSQL -c "SELECT boyut_tipi, count(*) FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='ciro_lastik' GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "1. DEPLOY — normalize fonksiyonlari + backfill(segment,sezon) + footprint, tek transaction"
$PSQLI <<'SQL'
BEGIN;

CREATE OR REPLACE FUNCTION public.kategori_segment(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE
    WHEN p LIKE '%YENİLEME%' THEN 'YENİLEME'
    WHEN p LIKE '%TAMİR%'    THEN 'TAMİR'
    WHEN p LIKE '%2.EL%'     THEN '2.EL'
    WHEN p IN ('YAZ','KIS','4 MEVSIM') THEN 'PSR'
    WHEN p LIKE 'TBR%'    THEN 'TBR'
    WHEN p LIKE 'OTR%'    THEN 'OTR'
    WHEN p LIKE 'LSR%'    THEN 'LSR'
    WHEN p LIKE 'IND%'    THEN 'IND'
    WHEN p = 'AG'         THEN 'AG'
    WHEN p LIKE 'KARKAS%' THEN 'KARKAS'
    ELSE COALESCE(NULLIF(btrim(p),''),'DIGER')
  END;
$fn$;

CREATE OR REPLACE FUNCTION public.kategori_sezon(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE p WHEN 'YAZ' THEN 'YAZ' WHEN 'KIS' THEN 'KIŞ' WHEN '4 MEVSIM' THEN '4 MEVSIM' ELSE '(sezon yok)' END;
$fn$;

DELETE FROM bi_metrik_gecmis
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND metrik='ciro_lastik' AND boyut_tipi IN ('segment','sezon');

INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, boyut_tipi, boyut_deger, meta, hesaplanma_at)
SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','ciro_lastik','ay', ay, round(sum(ciro)), 'TL','kesin','bi_marj_atom','segment', kategori_segment(kategori),
       '{"kaynak_fn":"kategori_segment"}'::jsonb, now()
FROM bi_marj_atom WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
GROUP BY ay, kategori_segment(kategori);

INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, boyut_tipi, boyut_deger, meta, hesaplanma_at)
SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','ciro_lastik','ay', ay, round(sum(ciro)), 'TL','kesin','bi_marj_atom','sezon', kategori_sezon(kategori),
       '{"kaynak_fn":"kategori_sezon"}'::jsonb, now()
FROM bi_marj_atom WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
GROUP BY ay, kategori_sezon(kategori);

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'omurga_71',
  'Boyut (B): ciro_lastik x SEGMENT + x SEZON omurgaya. Normalize fn kategori_segment/kategori_sezon (atom.kategori). Fatih karari: YENILEME ve TAMIR AYRI segment.',
  'Cockpit pivot ekseni: marka tek boyuttu; segment (PSR/TBR/OTR/LSR/IND/AG/KARKAS/YENILEME/TAMIR/2.EL) + sezon (YAZ/KIS/4MEVSIM) lastik isinin ekseni. Kaynak atom (kategori+ciro). LIKE ile eslesme (TR I tuzagi -> ILIKE degil).',
  '{"tur":"DB-only","yeni_fn":["kategori_segment","kategori_sezon"],"metrik":"ciro_lastik","boyutlar":["segment","sezon"],"karar":"YENILEME+TAMIR ayri segment","script":"omurga_71_segment_sezon.sh"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_71');

COMMIT;
SQL

hr "2. IÇ TUTARLILIK — segment toplami = sezon toplami (ikisi de atom-ciro; birebir olmali)"
$PSQL -c "SELECT
   (SELECT round(sum(deger)) FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='ciro_lastik' AND boyut_tipi='segment') AS segment_toplam,
   (SELECT round(sum(deger)) FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='ciro_lastik' AND boyut_tipi='sezon')   AS sezon_toplam;" 2>&1 | sed 's/^/  /'

hr "3. YENI DAGILIM — ciro_lastik artik hangi boyutlarda"
$PSQL -c "SELECT boyut_tipi, count(*) satir, count(DISTINCT boyut_deger) deger, max(donem)::date son FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='ciro_lastik' GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "4. SON 12 AY — SEGMENT bazinda ciro + ORTALAMA marj (insight: hangi segment karli)"
$PSQL -c "SELECT kategori_segment(kategori) segment, round(sum(ciro)/1e6,1) ciro_M, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1) marj_pct, sum(adet)::int adet
  FROM bi_marj_atom WHERE tenant_id::text='$T' AND ay >= (CURRENT_DATE - INTERVAL '12 months')
  GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'

hr "5. SON 12 AY — SEZON bazinda ciro + marj"
$PSQL -c "SELECT kategori_sezon(kategori) sezon, round(sum(ciro)/1e6,1) ciro_M, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1) marj_pct
  FROM bi_marj_atom WHERE tenant_id::text='$T' AND ay >= (CURRENT_DATE - INTERVAL '12 months')
  GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'

hr "BITTI — (2) segment_toplam=sezon_toplam (iç tutarlılık); (3) ciro_lastik artık segment+sezon boyutlu; (4/5) hangi segment/sezon kârlı = cockpit içgörüsü. Sonra .md footprint."
