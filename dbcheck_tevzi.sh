#!/usr/bin/env bash
# READ-ONLY — OTOMOTİV LASTİKLERİ TEVZİ: müşteri mi tedarikçi mi? Satış/alış/bakiye ile ilişki teyidi.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
\echo '===== 1) CARİ RİSK kaydı (bi_musteri_risk) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, left(muhatap_adi,34) ad, musteri_mi, left(COALESCE(grup,'—'),18) grup,
  left(COALESCE(odeme_kosulu,'—'),18) vade, round(hesap_bakiyesi/1e6,2) hesap_bak_M,
  round(vadesi_gecmis/1e6,2) gecikmis_M, round(toplam_risk/1e6,2) toplam_risk_M, left(COALESCE(satis_calisani,'—'),16) temsilci
FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t
WHERE muhatap_adi ILIKE '%TEVZ%'
ORDER BY muhatap_kodu, export_date DESC;

\echo ''
\echo '===== 2) KRB bu firmaya SATIŞ yaptı mı? (bi_satis_faturalari, 12 ay) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT count(*) fatura_satiri, round(SUM(satir_tutar)/1e6,1) satis_M,
  to_char(min(fatura_tarihi),'YYYY-MM-DD') ilk, to_char(max(fatura_tarihi),'YYYY-MM-DD') son
FROM bi_satis_faturalari s JOIN tn ON s.tenant_id::text=tn.t
WHERE musteri_adi ILIKE '%TEVZ%' AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months';

\echo ''
\echo '===== 3) KRB bu firmadan ALIŞ yaptı mı? (bi_tedarikci_faturalari, 12 ay) ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT count(*) fatura_satiri, round(SUM(satir_kdv_haric)/1e6,1) alis_M,
  to_char(min(fatura_tarihi),'YYYY-MM-DD') ilk, to_char(max(fatura_tarihi),'YYYY-MM-DD') son
FROM bi_tedarikci_faturalari t JOIN tn ON t.tenant_id::text=tn.t
WHERE tedarikci_adi ILIKE '%TEVZ%' AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months';

\echo ''
\echo '===== 4) Bağlı Muhatap Bakiyeleri (bi_cari_bakiye) — net pozisyon ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT left(COALESCE(musteri_kodu,tedarikci_kodu),14) kod, left(COALESCE(tedarikci_adi,''),34) ad,
  round(musteri_bakiye/1e6,2) musteri_bakiye_M, round(tedarikci_bakiye/1e6,2) krb_borc_M, round(net_pozisyon/1e6,2) net_M
FROM bi_cari_bakiye c JOIN tn ON c.tenant_id::text=tn.t
WHERE tedarikci_adi ILIKE '%TEVZ%' OR musteri_kodu IN
  (SELECT DISTINCT muhatap_kodu FROM bi_musteri_risk m2 JOIN tn ON m2.tenant_id::text=tn.t WHERE muhatap_adi ILIKE '%TEVZ%');
SQL
echo "== DONE =="
