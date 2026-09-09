#!/usr/bin/env bash
# READ-ONLY — DSO reconciliation: nominal vade (43) -> realized DSO (138) köprüsü.
# Alacak on-term vs gecikmiş, ciro paydası, vade dağılımı. Hiçbir yazma yok.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
\echo '===== 1) SAKLI DSO / ALACAK SERİSİ (kokpit bunu gösterir) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT metrik, to_char(donem,'YYYY-MM') ay, round(deger,1) deger
FROM bi_metrik_gecmis m JOIN tn ON m.tenant_id::text=tn.t
WHERE boyut_tipi='sirket' AND periyot='ay' AND metrik IN ('dso','alacak','ciro_lastik','stok_deger')
  AND donem >= (CURRENT_DATE - INTERVAL '15 months')
ORDER BY metrik, donem;

\echo ''
\echo '===== 2) ALACAK KÖPRÜSÜ: on-term vs gecikmiş, ima edilen DSO ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
rev AS (
  SELECT
    SUM(satir_tutar) FILTER (WHERE fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months')                          AS rev12,
    SUM(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE) - INTERVAL '1 month'
                              AND fatura_tarihi <  date_trunc('month',CURRENT_DATE))                               AS rev_sonay
  FROM bi_satis_faturalari s JOIN tn ON s.tenant_id::text=tn.t WHERE satir_tutar>0),
risk AS (
  SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, toplam_risk, vadesi_gecmis, musteri_mi
  FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t
  ORDER BY muhatap_kodu, export_date DESC),
ragg AS (
  SELECT SUM(GREATEST(hesap_bakiyesi,0)) bakiye_poz, SUM(hesap_bakiyesi) bakiye_net,
         SUM(GREATEST(vadesi_gecmis,0))  gecikmis,    SUM(toplam_risk) risk_top
  FROM risk WHERE musteri_mi)
SELECT
  round(rev12/1e6,1)                                        AS ciro_12ay_M,
  round(rev_sonay/1e6,1)                                    AS ciro_sonay_M,
  round(rev12/365.0/1e6,3)                                  AS gunluk_ciro_M,
  round(bakiye_poz/1e6,1)                                   AS alacak_poz_M,
  round(gecikmis/1e6,1)                                     AS gecikmis_M,
  round((bakiye_poz-gecikmis)/1e6,1)                        AS vadesinde_M,
  round(gecikmis/nullif(bakiye_poz,0)*100,1)               AS gecikmis_pct,
  round(bakiye_poz/nullif(rev12/365.0,0),1)                AS ima_DSO_toplam,
  round((bakiye_poz-gecikmis)/nullif(rev12/365.0,0),1)     AS ima_DSO_vadesinde,
  round(gecikmis/nullif(rev12/365.0,0),1)                  AS ima_DSO_gecikmis
FROM rev, ragg;

\echo ''
\echo '===== 3) VADE DAĞILIMI (nominal 43 gün neyden geliyor — peşin payı) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
b AS (
  SELECT COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') kosul, SUM(satir_tutar) tut
  FROM bi_satis_faturalari s JOIN tn ON s.tenant_id::text=tn.t
  WHERE satir_tutar>0 AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months' GROUP BY 1)
SELECT kosul, round(tut/1e6,1) tutar_M, round(100*tut/SUM(tut) OVER(),1) pct
FROM b ORDER BY tut DESC LIMIT 15;

\echo ''
\echo '===== 4) FATURA-İÇİ GERÇEK VADE (vade_tarihi - fatura_tarihi), ciro ağırlıklı ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT
  round(SUM((vade_tarihi-fatura_tarihi)*satir_tutar)::numeric / nullif(SUM(satir_tutar),0),1) AS agirlikli_vade_gun,
  round(100.0*SUM(satir_tutar) FILTER (WHERE vade_tarihi IS NULL OR vade_tarihi<=fatura_tarihi)/nullif(SUM(satir_tutar),0),1) AS pesin_pct
FROM bi_satis_faturalari s JOIN tn ON s.tenant_id::text=tn.t
WHERE satir_tutar>0 AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months';
SQL
echo "== DONE =="
