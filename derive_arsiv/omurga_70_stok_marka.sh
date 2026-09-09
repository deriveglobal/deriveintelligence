#!/usr/bin/env bash
# DEPLOY omurga_70 — §6.5 boyut (A): stok_deger x MARKA omurgaya. DB-only, rebuild YOK.
# metrik_stok_deger_recon ile AYNI degerleme (qty x ort-alis-maliyet, asof), sadece GROUP BY marka.
# Sirket toplami = marka toplami insaen birebir -> reconciliation KANITI.
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform"
PSQLI="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. BAZ — mevcut stok_deger x marka satiri (0 bekleniyor) + sirket stok_deger son deger"
$PSQL -c "SELECT boyut_tipi, count(*) FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='stok_deger' GROUP BY 1;" 2>&1 | sed 's/^/  /'

hr "1. DEPLOY — fonksiyon + backfill(son 13 ay) + footprint, tek transaction"
$PSQLI <<'SQL'
BEGIN;

CREATE OR REPLACE FUNCTION public.metrik_stok_deger_marka(p_tenant uuid, p_asof date)
RETURNS TABLE(marka text, deger numeric)
LANGUAGE sql STABLE AS $fn$
  WITH q AS (
    SELECT COALESCE(NULLIF(btrim(marka),''),'(marka yok)') AS marka, kalem_kodu,
           sum(giris)-sum(cikis) AS qty,
           sum(giris_tutari) FILTER (WHERE giris>0) AS gt,
           sum(giris)        FILTER (WHERE giris>0) AS g
      FROM bi_stok_hareket
     WHERE tenant_id=p_tenant AND belge_tarihi < p_asof
     GROUP BY 1, kalem_kodu
  )
  SELECT q.marka, round(sum(GREATEST(qty,0)*(gt/g))) AS deger
  FROM q WHERE g>0
  GROUP BY q.marka
  HAVING sum(GREATEST(qty,0)*(gt/g)) >= 1;
$fn$;

DELETE FROM bi_metrik_gecmis
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND metrik='stok_deger' AND boyut_tipi='marka';

INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, boyut_tipi, boyut_deger, meta, hesaplanma_at)
SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'stok_deger', 'ay', m.donem, s.deger, 'TL', 'kesin', 'bi_stok_hareket', 'marka', s.marka,
       '{"kaynak_fn":"metrik_stok_deger_marka"}'::jsonb, now()
FROM (SELECT gs::date AS donem, (gs + interval '1 month')::date AS asof
      FROM generate_series(date_trunc('month', CURRENT_DATE) - interval '12 months', date_trunc('month', CURRENT_DATE), interval '1 month') gs) m
CROSS JOIN LATERAL metrik_stok_deger_marka('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid, m.asof) s;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'omurga_70',
  'Boyut (A): stok_deger x MARKA omurgaya (bi_metrik_gecmis). Yeni fn metrik_stok_deger_marka (recon ile ayni degerleme, GROUP BY marka); son 13 ay backfill.',
  'Cockpit marka karti eksigi: ciro+marj marka bazliydi ama stok sirket-geneliydi. Stok x marka = marka maruziyeti; zararina_hacim yasasini aksiyona baglar (zarar eden markada ne kadar stok bagli). Sirket toplami=marka toplami insaen birebir (reconciliation).',
  '{"tur":"DB-only","yeni_fn":"metrik_stok_deger_marka(tenant,asof)","metrik":"stok_deger","boyut":"marka","donem":"son 13 ay","script":"omurga_70_stok_marka.sh"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_70');

COMMIT;
SQL

hr "2. RECONCILIATION KANITI — marka toplami = sirket recon (ayni asof, birebir olmali)"
$PSQL -c "SELECT round((SELECT sum(deger) FROM metrik_stok_deger_marka('$T'::uuid, (date_trunc('month',CURRENT_DATE)+interval '1 month')::date))) AS marka_toplam,
                 round(metrik_stok_deger_recon('$T'::uuid, (date_trunc('month',CURRENT_DATE)+interval '1 month')::date)) AS sirket_recon;" 2>&1 | sed 's/^/  /'

hr "3. YENI DAGILIM — stok_deger artik hangi boyutlarda + kaç satır"
$PSQL -c "SELECT boyut_tipi, count(*) satir, count(DISTINCT boyut_deger) marka, max(donem)::date son FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='stok_deger' GROUP BY 1;" 2>&1 | sed 's/^/  /'

hr "4. SON AY — marka bazında stok değeri (top 12)"
$PSQL -c "SELECT boyut_deger marka, round(deger) stok_TL FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='stok_deger' AND boyut_tipi='marka' AND donem=(SELECT max(donem) FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='stok_deger' AND boyut_tipi='marka') ORDER BY deger DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "5. ZARARINA_HACIM BAĞI — SAILUN stok maruziyeti (zarar eden markada bağlı stok)"
$PSQL -c "SELECT boyut_deger marka, round(deger) stok_TL FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='stok_deger' AND boyut_tipi='marka' AND boyut_deger='SAILUN' ORDER BY donem DESC LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "BITTI — BEKLE: (2) marka_toplam ≈ sirket_recon (birebir=doğru bölüm); (3) stok_deger artık marka boyutlu; (4/5) marka stok tablosu + SAILUN maruziyeti. Sonra .md footprint + boyut (B) segment/sezon önerisi."
