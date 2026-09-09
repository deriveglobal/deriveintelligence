#!/usr/bin/env bash
# READ-ONLY — 12 ay brüt kâr + marj (bi_marj_atom), ve overdue finansman maliyetinin kâra oranı.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
\echo '===== 12 AY BRÜT KÂR / MARJ + OVERDUE FİNANSMAN ETKİSİ ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_marj_atom GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
kar AS (
  SELECT SUM(ciro) ciro, SUM(brut_kar) brut_kar
  FROM bi_marj_atom m JOIN tn ON m.tenant_id::text=tn.t
  WHERE ay >= (CURRENT_DATE - INTERVAL '12 months')),
ov AS (
  SELECT SUM(GREATEST(vadesi_gecmis,0)) gecikmis
  FROM (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, vadesi_gecmis, musteri_mi
        FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t
        ORDER BY muhatap_kodu, export_date DESC) r
  WHERE musteri_mi)
SELECT
  round(kar.ciro/1e6,1)                                   AS ciro_12ay_M,
  round(kar.brut_kar/1e6,1)                               AS brut_kar_12ay_M,
  round(100*kar.brut_kar/nullif(kar.ciro,0),1)           AS brut_marj_pct,
  round(ov.gecikmis/1e6,1)                                AS overdue_M,
  round(ov.gecikmis*0.40/1e6,1)                           AS finans_40_M,
  round(ov.gecikmis*0.50/1e6,1)                           AS finans_50_M,
  round(ov.gecikmis*0.60/1e6,1)                           AS finans_60_M,
  round(100*ov.gecikmis*0.50/nullif(kar.brut_kar,0),1)   AS finans50_brutkar_pct
FROM kar, ov;
SQL
echo "== DONE =="
