#!/usr/bin/env bash
# OMURGA 1 — CIRO PROVASI: metrik geçmişi omurgası uçtan uca. Deploy gerekmez (DB).
#   Desen: metrik = tarih-parametreli fonksiyon. Backfill (akış, 6 yıl kesin) + trend + snapshot.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TABLO — bi_metrik_gecmis (append-only, tenant-scoped, GÜVEN kolonlu)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_metrik_gecmis (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL,
  metrik         text NOT NULL,                 -- 'ciro_lastik', 'dso', ...
  periyot        text NOT NULL,                 -- 'ay' | 'gun' | 'ceyrek'
  donem          date NOT NULL,                 -- temsil ettiği dönem (ör. 2026-06-01)
  deger          numeric NOT NULL,
  birim          text,
  guven          text NOT NULL DEFAULT 'kesin', -- kesin | yaklasik | snapshot
  kaynak         text,
  kaynak_export_date date,                       -- pozisyon metriği hangi ERP fotoğrafından
  meta           jsonb DEFAULT '{}'::jsonb,      -- {tam:true/false, ...}
  hesaplanma_at  timestamptz DEFAULT now(),
  UNIQUE (tenant_id, metrik, periyot, donem)     -- idempotent
);
CREATE INDEX IF NOT EXISTS idx_metrik_gecmis ON bi_metrik_gecmis (tenant_id, metrik, periyot, donem);
ALTER TABLE bi_metrik_gecmis ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_metrik_gecmis ON bi_metrik_gecmis;
CREATE POLICY p_metrik_gecmis ON bi_metrik_gecmis USING (true);  -- app-katmanı tenant filtreli; RLS açık
SQL
echo "  ✅ tablo hazır (RLS açık, UNIQUE idempotent, güven kolonu var)"

hr "2. FONKSIYON — ciro(tenant, ay) tarih-parametreli (desen: metrik=fonksiyon)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- ⚠ bi_satis_faturalari.tenant_id TEXT — cast.
CREATE OR REPLACE FUNCTION metrik_ciro(p_tenant uuid, p_ay date, p_lastik_only boolean)
RETURNS numeric AS $$
  SELECT COALESCE(sum(satir_tutar),0)
    FROM bi_satis_faturalari
   WHERE tenant_id = p_tenant::text AND miktar > 0
     AND (NOT p_lastik_only OR ebat IS NOT NULL)
     AND fatura_tarihi >= p_ay AND fatura_tarihi < (p_ay + interval '1 month');
$$ LANGUAGE sql STABLE;
SQL
echo "  ✅ metrik_ciro(tenant, ay, lastik_mi) — her ay için canlı hesaplar"

hr "3. BACKFILL — 2021-10 → bugün, ciro_lastik + ciro_tum (akış = KESİN, 6 yıl)"
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
WITH aylar AS (
  SELECT generate_series(date '2021-10-01', date_trunc('month', CURRENT_DATE)::date, interval '1 month')::date AS ay
),
son_veri AS (SELECT max(fatura_tarihi) mx FROM bi_satis_faturalari WHERE tenant_id='$T')
INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, meta)
SELECT '$T'::uuid, m.metrik, 'ay', a.ay,
       metrik_ciro('$T'::uuid, a.ay, m.lastik), 'TL', 'kesin', 'bi_satis_faturalari',
       jsonb_build_object('tam', a.ay < date_trunc('month',(SELECT mx FROM son_veri)))
  FROM aylar a
  CROSS JOIN (VALUES ('ciro_lastik', true), ('ciro_tum', false)) AS m(metrik, lastik)
ON CONFLICT (tenant_id, metrik, periyot, donem)
  DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
$PSQL -c "SELECT metrik, count(*) ay_sayisi, min(donem)::text ilk_ay, max(donem)::text son_ay, round(sum(deger)/1e6,1) toplam_m FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik LIKE 'ciro%' GROUP BY 1;"

hr "4. ⚠ TREND OKUMA — son 15 ay + önceki aya (MoM) + geçen yıla (YoY) delta"
$PSQL -c "
SELECT to_char(donem,'YYYY-MM') ay,
       round(deger/1e6,1) ciro_m,
       round(100.0*(deger-lag(deger)   OVER w)/nullif(lag(deger)   OVER w,0)) mom_pct,
       round(100.0*(deger-lag(deger,12)OVER w)/nullif(lag(deger,12)OVER w,0)) yoy_pct,
       CASE WHEN (meta->>'tam')::boolean THEN '' ELSE 'KISMI' END nota
  FROM bi_metrik_gecmis
 WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND periyot='ay'
 WINDOW w AS (ORDER BY donem)
 ORDER BY donem DESC LIMIT 15;"
echo "  ⚠ İşte trend + değişim: kiracı 'neredeydi→nerede→nereye' görür. mom/yoy = içgörü/aksiyon tabanı."

hr "5. GÜNLÜK SNAPSHOT — bundan sonra her gün çalışacak (cron için tek satır)"
echo "  Komut (cron 08:00): içinde bulunulan ayı yeniden hesapla (idempotent upsert):"
echo "    docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \\"
echo "      \"INSERT INTO bi_metrik_gecmis(tenant_id,metrik,periyot,donem,deger,birim,guven,kaynak)"
echo "       SELECT '$T'::uuid,'ciro_lastik','ay',date_trunc('month',CURRENT_DATE)::date,"
echo "              metrik_ciro('$T'::uuid,date_trunc('month',CURRENT_DATE)::date,true),'TL','kesin','bi_satis_faturalari'"
echo "       ON CONFLICT(tenant_id,metrik,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger,hesaplanma_at=now();\""
echo "  ⚠ Bu, DESEN. DSO/stok/borç eklenince aynı tabloya (güven=yaklasik/snapshot) yazılır."

hr "6. KANIT — güven dağılımı + kısmi ay işaretli mi"
$PSQL -c "SELECT metrik, guven, count(*), count(*) FILTER (WHERE (meta->>'tam')::boolean=false) kismi
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid GROUP BY 1,2;"

hr "BITTI — CIRO geçmişi KALICI biriktiriliyor. Desen kanıtlandı; metrikler eklenebilir."
