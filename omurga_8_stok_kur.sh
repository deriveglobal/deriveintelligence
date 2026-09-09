#!/usr/bin/env bash
# OMURGA 8 — STOK değerini omurgaya kur. Geçmiş=recon(as-of maliyet, yaklasik). DB-only (cron sonraki adım).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. FONKSİYON — stok değeri recon (as-of miktar × AS-OF ağırlıklı ort maliyet)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- as_of'ta: kalem başına net miktar (Σgiris−Σcikis, o tarihe kadar) × o tarihe kadarki ağırlıklı ort maliyet.
-- as-of maliyet = enflasyon şişirmesini önler. YAKLAŞIK (~%4 bugün; hayalet ucuz kalemler).
CREATE OR REPLACE FUNCTION metrik_stok_deger_recon(p_tenant uuid, p_asof date)
RETURNS numeric AS $$
  WITH q AS (
    SELECT kalem_kodu,
           sum(giris)-sum(cikis) AS qty,
           sum(giris_tutari) FILTER (WHERE giris>0) AS gt,
           sum(giris)        FILTER (WHERE giris>0) AS g
      FROM bi_stok_hareket
     WHERE tenant_id = p_tenant AND belge_tarihi < p_asof
     GROUP BY kalem_kodu
  )
  SELECT COALESCE(sum(GREATEST(qty,0) * (gt/g)),0) FROM q WHERE g>0;
$$ LANGUAGE sql STABLE;
SQL
echo "  ✅ metrik_stok_deger_recon kuruldu (as-of maliyet, tenant-scoped bi_stok_hareket)"

hr "2. BACKFILL — aylık stok değeri (recon, yaklasik). Hareket başlangıcı +3 aydan (settle)."
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
WITH sinir AS (
  SELECT (date_trunc('month', min(belge_tarihi)) + interval '3 month')::date AS bas,
         date_trunc('month', max(belge_tarihi))::date AS son_veri
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid
),
aylar AS (
  SELECT generate_series((SELECT bas FROM sinir), date_trunc('month',CURRENT_DATE)::date, interval '1 month')::date AS ay
)
INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, meta)
SELECT '$T'::uuid, 'stok_deger', 'ay', a.ay,
       round(metrik_stok_deger_recon('$T'::uuid, a.ay)), 'TL', 'yaklasik', 'reconstruction',
       jsonb_build_object('tam', a.ay < (SELECT son_veri FROM sinir),
                          'yontem','as-of miktar × as-of ağırlıklı ort maliyet; eski kesilmiş kalemler hafif fazla')
  FROM aylar a
ON CONFLICT (tenant_id, metrik, periyot, donem)
  DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
$PSQL -c "SELECT metrik, count(*) ay, min(donem)::text ilk, max(donem)::text son FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='stok_deger' GROUP BY 1;"

hr "3. ⚠ TREND — stok değeri son 15 ay (kış destoku → Brisa yığma hikâyesi görünmeli)"
$PSQL -c "SELECT to_char(donem,'YYYY-MM') ay, round(deger/1e6,1) stok_m,
                 round(100.0*(deger-lag(deger) OVER w)/nullif(lag(deger) OVER w,0)) mom_pct
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='stok_deger' AND periyot='ay'
          WINDOW w AS (ORDER BY donem) ORDER BY donem DESC LIMIT 15;"
echo "  ⚠ Geçmiş 'yaklasik' (recon). Bugün+ileri snapshot kesin gelecek (cron adımı — 235,4M)."

hr "4. KANIT — güven + en güncel recon değeri (bugünkü gerçek 235,4M'ye yakın mı)"
$PSQL -c "SELECT guven, count(*) FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='stok_deger' GROUP BY 1;"
$PSQL -c "SELECT round(metrik_stok_deger_recon('$T'::uuid, CURRENT_DATE+1)/1e6,1) AS bugun_recon_m,
                 (SELECT round(sum(a.adet*(km.gt/km.g))/1e6,1)
                    FROM bi_stok_anlik a JOIN (SELECT kalem_kodu, sum(giris_tutari) gt, sum(giris) g
                         FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu) km
                         ON km.kalem_kodu=a.kalem_kodu WHERE a.tenant_id='$T'::uuid AND a.adet>0) AS gercek_snapshot_m;"
echo "  ⚠ İkisi yakınsa (244 vs 235) recon meşru; fark hayalet ucuz kalemler + as-of maliyet."

hr "BITTI — STOK omurgada (recon geçmiş). Sonraki: cron'a bugün+ileri KESİN snapshot ekle."
