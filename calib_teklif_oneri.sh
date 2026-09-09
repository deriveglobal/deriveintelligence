#!/usr/bin/env bash
# TEKLIF_ONERI_V1 — amber-esigi kalibrasyonu (auth GEREKMEZ, dogrudan DB).
#   Soru: "rep normal fiyat girse yesil gorebilecek mi, yoksa her sey amber/kirmizi mi?"
#   hedef_taban = GREATEST((lo+hi)/2, maliyet/(1-marka_hedef)) ~ yesil/amber sinir FIYATI.
#   Yesil = girilen >= hedef_taban. Bunu gercek satis fiyatlariyla (med=p50, hi=p90) kiyasliyoruz.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash calib_teklif_oneri.sh'
set -euo pipefail
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -v ON_ERROR_STOP=1'
echo "=== DAGILIM (aktif tenant, son 12 ay, adet>=20 SKU) ==="
$PSQL <<'SQL'
WITH t AS (SELECT id::text tid FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1),
sku AS (
  SELECT s.kalem_kodu,
    percentile_cont(0.25) WITHIN GROUP (ORDER BY s.birim_fiyat) lo,
    percentile_cont(0.5)  WITHIN GROUP (ORDER BY s.birim_fiyat) med,
    percentile_cont(0.9)  WITHIN GROUP (ORDER BY s.birim_fiyat) hi,
    SUM(s.miktar) adet
  FROM bi_satis_faturalari s, t
  WHERE s.tenant_id::text=t.tid AND s.grup_adi LIKE 'LASTIK%' AND s.miktar>0
    AND s.fatura_tarihi>=(CURRENT_DATE-INTERVAL '12 months')
    AND (s.para_birimi IS NULL OR upper(s.para_birimi) IN ('TRY','TL'))
  GROUP BY s.kalem_kodu HAVING SUM(s.miktar)>=20),
cost AS (
  SELECT m.kalem_kodu, (SUM(m.ciro)-SUM(m.brut_kar))/NULLIF(SUM(m.adet),0) cost, MAX(m.marka) marka
  FROM bi_marj_atom m, t
  WHERE m.tenant_id::text=t.tid AND m.ay>=(CURRENT_DATE-INTERVAL '12 months')
  GROUP BY m.kalem_kodu),
brand AS (
  SELECT marka, GREATEST(0.12, LEAST(0.30, percentile_cont(0.6) WITHIN GROUP (ORDER BY mm))) bh
  FROM (SELECT a.marka, a.kalem_kodu, SUM(a.brut_kar)/NULLIF(SUM(a.ciro),0) mm
        FROM bi_marj_atom a, t
        WHERE a.tenant_id::text=t.tid AND a.ebat IS NOT NULL AND a.ebat<>'' AND a.ay>=(CURRENT_DATE-INTERVAL '12 months')
        GROUP BY a.marka, a.kalem_kodu HAVING SUM(a.adet)>=20 AND SUM(a.ciro)>0) z
  GROUP BY marka),
calc AS (
  SELECT s.kalem_kodu, round(s.med) med, round(s.hi) hi, round(c.cost) cost,
    round(COALESCE(b.bh,0.12)*1000)/10 brand_pct,
    round(GREATEST((s.lo+s.hi)/2.0, c.cost/(1-COALESCE(b.bh,0.12)))) hedef_taban
  FROM sku s JOIN cost c USING (kalem_kodu) LEFT JOIN brand b ON b.marka=c.marka
  WHERE c.cost IS NOT NULL AND c.cost>0)
SELECT
  count(*)                                                                    n_sku,
  round(avg(brand_pct)::numeric,1)                                            ort_marka_hedef_pct,
  count(*) FILTER (WHERE hedef_taban <= med)                                  yesil_medyanda,
  round((100.0*count(*) FILTER (WHERE hedef_taban<=med)/count(*))::numeric,1) pct_yesil_medyanda,
  count(*) FILTER (WHERE hedef_taban > med AND hedef_taban <= hi)             amber_med_ile_p90,
  count(*) FILTER (WHERE hedef_taban > hi)                                    hedef_p90_ustu,
  round((100.0*count(*) FILTER (WHERE hedef_taban>hi)/count(*))::numeric,1)   pct_hedef_p90_ustu
FROM calc;
SQL
echo ""
echo "=== ORNEK 15 SKU (hedef_taban vs med/p90) ==="
$PSQL <<'SQL'
WITH t AS (SELECT id::text tid FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1),
sku AS (
  SELECT s.kalem_kodu,
    percentile_cont(0.25) WITHIN GROUP (ORDER BY s.birim_fiyat) lo,
    percentile_cont(0.5)  WITHIN GROUP (ORDER BY s.birim_fiyat) med,
    percentile_cont(0.9)  WITHIN GROUP (ORDER BY s.birim_fiyat) hi,
    SUM(s.miktar) adet
  FROM bi_satis_faturalari s, t
  WHERE s.tenant_id::text=t.tid AND s.grup_adi LIKE 'LASTIK%' AND s.miktar>0
    AND s.fatura_tarihi>=(CURRENT_DATE-INTERVAL '12 months')
    AND (s.para_birimi IS NULL OR upper(s.para_birimi) IN ('TRY','TL'))
  GROUP BY s.kalem_kodu HAVING SUM(s.miktar)>=20),
cost AS (
  SELECT m.kalem_kodu, (SUM(m.ciro)-SUM(m.brut_kar))/NULLIF(SUM(m.adet),0) cost, MAX(m.marka) marka, MAX(m.ebat) ebat
  FROM bi_marj_atom m, t
  WHERE m.tenant_id::text=t.tid AND m.ay>=(CURRENT_DATE-INTERVAL '12 months')
  GROUP BY m.kalem_kodu),
brand AS (
  SELECT marka, GREATEST(0.12, LEAST(0.30, percentile_cont(0.6) WITHIN GROUP (ORDER BY mm))) bh
  FROM (SELECT a.marka, a.kalem_kodu, SUM(a.brut_kar)/NULLIF(SUM(a.ciro),0) mm
        FROM bi_marj_atom a, t
        WHERE a.tenant_id::text=t.tid AND a.ebat IS NOT NULL AND a.ebat<>'' AND a.ay>=(CURRENT_DATE-INTERVAL '12 months')
        GROUP BY a.marka, a.kalem_kodu HAVING SUM(a.adet)>=20 AND SUM(a.ciro)>0) z
  GROUP BY marka)
SELECT c.marka, c.ebat, s.adet::int,
  round(c.cost) maliyet, round(COALESCE(b.bh,0.12)*1000)/10 hedef_pct,
  round(s.med) med_p50, round(s.hi) p90,
  round(GREATEST((s.lo+s.hi)/2.0, c.cost/(1-COALESCE(b.bh,0.12)))) hedef_taban,
  CASE WHEN round(GREATEST((s.lo+s.hi)/2.0, c.cost/(1-COALESCE(b.bh,0.12)))) <= round(s.med) THEN 'yesil@medyan'
       WHEN round(GREATEST((s.lo+s.hi)/2.0, c.cost/(1-COALESCE(b.bh,0.12)))) <= round(s.hi)  THEN 'amber@medyan'
       ELSE 'p90-ustu' END durum
FROM sku s JOIN cost c USING (kalem_kodu) LEFT JOIN brand b ON b.marka=c.marka
WHERE c.cost IS NOT NULL AND c.cost>0
ORDER BY s.adet DESC LIMIT 15;
SQL
echo ""
echo "=== TEST ICIN 5 ORNEK (musteri_id + kalem_kodu) — tarayicida deneyebilirsin ==="
$PSQL <<'SQL'
SELECT st.musteri_id, st.kalem_kodu, st.marka, st.ebat
FROM saha_teklif st
WHERE st.kalem_kodu IS NOT NULL AND st.musteri_id IS NOT NULL
ORDER BY st.created_at DESC LIMIT 5;
SQL
