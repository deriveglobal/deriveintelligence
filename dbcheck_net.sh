#!/usr/bin/env bash
# READ-ONLY — NET pozisyon etkisi: bi_cari_bakiye (musteri_bakiye + tedarikci_bakiye = net_pozisyon).
# Gecikmiş alacak brüt vs net; en büyük gecikmiş hesaplar KRB borcuyla mahsuplaşınca ne oluyor?
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
\echo '===== 0) bi_cari_bakiye kolonları + tazelik ====='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='bi_cari_bakiye' ORDER BY ordinal_position;

\echo ''
\echo '===== 1) TOPLAM: brüt alacak vs KRB borcu vs net ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
b AS (SELECT * FROM bi_cari_bakiye c JOIN tn ON c.tenant_id::text=tn.t)
SELECT count(*) muhatap_n,
  count(*) FILTER (WHERE tedarikci_bakiye < -1e5) krb_borclu_adet,
  round(SUM(musteri_bakiye)/1e6,1)   brut_alacak_M,
  round(SUM(LEAST(tedarikci_bakiye,0))/1e6,1) krb_borc_M,
  round(SUM(net_pozisyon)/1e6,1)     net_pozisyon_M,
  max(export_date) son_tarih
FROM b;

\echo ''
\echo '===== 2) EN BÜYÜK GECİKMİŞ HESAPLAR: brüt gecikmiş vs KRB borcu vs net ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, satis_calisani,
        GREATEST(vadesi_gecmis,0) vg
      FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t
      WHERE musteri_mi ORDER BY muhatap_kodu, export_date DESC)
SELECT left(r.muhatap_adi,28) musteri, left(COALESCE(r.satis_calisani,'—'),14) temsilci,
  round(r.vg/1e6,1) gecikmis_brut_M,
  round(COALESCE(b.tedarikci_bakiye,0)/1e6,1) krb_borc_M,
  round(GREATEST(r.vg + LEAST(COALESCE(b.tedarikci_bakiye,0),0),0)/1e6,1) gecikmis_net_M
FROM r LEFT JOIN bi_cari_bakiye b ON b.tenant_id::text=(SELECT t FROM tn) AND b.musteri_kodu=r.muhatap_kodu
WHERE r.vg>0 ORDER BY r.vg DESC LIMIT 15;

\echo ''
\echo '===== 3) GECİKMİŞ TOPLAM: brüt vs KRB-borcuyla mahsuplaşmış net ====='
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, GREATEST(vadesi_gecmis,0) vg
      FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t
      WHERE musteri_mi ORDER BY muhatap_kodu, export_date DESC)
SELECT round(SUM(r.vg)/1e6,1) gecikmis_brut_M,
  round(SUM(GREATEST(r.vg + LEAST(COALESCE(b.tedarikci_bakiye,0),0),0))/1e6,1) gecikmis_net_M,
  round((SUM(r.vg) - SUM(GREATEST(r.vg + LEAST(COALESCE(b.tedarikci_bakiye,0),0),0)))/1e6,1) mahsup_M
FROM r LEFT JOIN bi_cari_bakiye b ON b.tenant_id::text=(SELECT t FROM tn) AND b.musteri_kodu=r.muhatap_kodu;
SQL
echo "== DONE =="
