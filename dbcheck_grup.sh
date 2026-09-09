#!/usr/bin/env bash
# READ-ONLY — Gecikmiş alacak, muhatap GRUP'una göre. TEDARİKÇİ grubu müşteri riski DEĞİL (phantom).
# hesap_bakiyesi=0 ama vadesi_gecmis>0 olanları da ayıkla. Gerçek müşteri gecikmişi + doğru top liste.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
\echo '===== 1) GECİKMİŞ, GRUP bazında (hangi grup taşıyor?) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(grup),''),'—') grup,
        GREATEST(vadesi_gecmis,0) vg, GREATEST(hesap_bakiyesi,0) bak
      FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t WHERE musteri_mi
      ORDER BY muhatap_kodu, export_date DESC)
SELECT grup, count(*) FILTER (WHERE vg>0) gecikmis_hesap,
  round(SUM(vg)/1e6,1) gecikmis_M, round(SUM(bak)/1e6,1) hesap_bakiye_M
FROM r GROUP BY grup ORDER BY SUM(vg) DESC;

\echo ''
\echo '===== 2) PHANTOM: hesap_bakiyesi=0 ama gecikmiş>0 (gerçek alacak değil) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(grup),''),'—') grup,
        GREATEST(vadesi_gecmis,0) vg, GREATEST(hesap_bakiyesi,0) bak
      FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t WHERE musteri_mi
      ORDER BY muhatap_kodu, export_date DESC)
SELECT
  round(SUM(vg)/1e6,1) toplam_gecikmis_M,
  round(SUM(vg) FILTER (WHERE bak<=0)/1e6,1) bakiyesiz_gecikmis_M,
  round(SUM(vg) FILTER (WHERE grup ILIKE '%TEDAR%')/1e6,1) tedarikci_grup_M,
  round(SUM(vg) FILTER (WHERE grup NOT ILIKE '%TEDAR%' AND bak>0)/1e6,1) gercek_musteri_gecikmis_M
FROM r;

\echo ''
\echo '===== 3) GERÇEK MÜŞTERİ top gecikmiş (TEDARİKÇİ grubu HARİÇ, bakiye>0) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, left(muhatap_adi,32) ad, COALESCE(NULLIF(TRIM(grup),''),'—') grup,
        GREATEST(vadesi_gecmis,0) vg, GREATEST(hesap_bakiyesi,0) bak
      FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t WHERE musteri_mi
      ORDER BY muhatap_kodu, export_date DESC)
SELECT ad, left(grup,16) grup, round(vg/1e6,1) gecikmis_M, round(bak/1e6,1) bakiye_M
FROM r WHERE vg>0 AND grup NOT ILIKE '%TEDAR%' AND bak>0
ORDER BY vg DESC LIMIT 12;
SQL
echo "== DONE =="
