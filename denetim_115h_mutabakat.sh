#!/usr/bin/env bash
# DENETIM_115H — Test A MUTABAKAT: acik kalem = 209M tutuyor mu? + gecmis rekonstruksiyon provasi. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. Anahtar TEKIL mi? (fatura_no + musteri_kodu cakisiyor mu)"
$PSQL -c "
SELECT count(*) AS satir, count(DISTINCT (fatura_no, musteri_kodu)) AS tekil_fatura
  FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid;"

hr "1. V1 — TOPLAM AGREGA: tum fatura − tum tahsilat = acik?"
$PSQL -c "
SELECT
  round((SELECT sum(satir_tutar) FROM bi_satis_faturalari WHERE tenant_id='$T')/1e6,1)          AS tum_fatura_m,
  round((SELECT sum(fatura_tutari) FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid)/1e6,1)   AS tum_tahsilat_m,
  round(((SELECT sum(satir_tutar) FROM bi_satis_faturalari WHERE tenant_id='$T')
        -(SELECT sum(fatura_tutari) FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid))/1e6,1) AS fark_acik_m;"
echo "  ⚠ fark_acik_m ~209 ise agrega tutuyor. Degilse iade/kismi odeme/kapsam farki var."

hr "2. V2 — FATURA DUZEYI: tahsilatta OLMAYAN faturalar (acik) toplami"
$PSQL -c "
WITH inv AS (
  SELECT fatura_no, musteri_kodu, min(fatura_tarihi) AS ft, sum(satir_tutar) AS tutar
    FROM bi_satis_faturalari WHERE tenant_id='$T'
    GROUP BY fatura_no, musteri_kodu),
paid AS (
  SELECT DISTINCT fatura_no, musteri_kodu FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid)
SELECT round(sum(inv.tutar) FILTER (WHERE p.fatura_no IS NULL)/1e6,1) AS acik_fatura_m,
       count(*)              FILTER (WHERE p.fatura_no IS NULL)       AS acik_fatura_adet,
       round(sum(inv.tutar) FILTER (WHERE p.fatura_no IS NOT NULL)/1e6,1) AS kapali_fatura_m
  FROM inv LEFT JOIN paid p ON p.fatura_no=inv.fatura_no AND p.musteri_kodu=inv.musteri_kodu;"
echo "  ⚠ acik_fatura_m ~209 ise: tahsilatta-olmayan = acik alacak. Rekonstruksiyon MUMKUN."

hr "3. ⚠ HEDEF karsilastir"
$PSQL -c "SELECT round(sum(hesap_bakiyesi)/1e6,1) AS erp_acik_alacak_m
          FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi;"

hr "4. ⚠ GECMIS PROVASI — 6 AY ONCE (2026-01-14) acik alacak KURULABILIR mi?"
echo "  Mantik: fatura_tarihi <= tarih VE (tahsilatta yok VEYA son_tahsilat > tarih) -> o tarihte ACIKTI"
$PSQL -c "
WITH gecmis AS (SELECT DATE '2026-01-14' AS d)
SELECT
  -- bugun (kontrol)
  round((SELECT sum(s.satir_tutar) FROM bi_satis_faturalari s
          LEFT JOIN (SELECT DISTINCT fatura_no,musteri_kodu,son_tahsilat FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid) t
            ON t.fatura_no=s.fatura_no AND t.musteri_kodu=s.musteri_kodu
         WHERE s.tenant_id='$T' AND (t.fatura_no IS NULL))/1e6,1)                          AS bugun_acik_m,
  -- 6 ay once
  round((SELECT sum(s.satir_tutar) FROM bi_satis_faturalari s
          LEFT JOIN (SELECT DISTINCT fatura_no,musteri_kodu,son_tahsilat FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid) t
            ON t.fatura_no=s.fatura_no AND t.musteri_kodu=s.musteri_kodu
         WHERE s.tenant_id='$T' AND s.fatura_tarihi <= (SELECT d FROM gecmis)
           AND (t.fatura_no IS NULL OR t.son_tahsilat > (SELECT d FROM gecmis)))/1e6,1)     AS alti_ay_once_acik_m;"
echo "  ⚠ Bu calisiyorsa: 6 yil boyunca HER GUN acik alacak (ve DSO) KESIN kurulabilir."

hr "BITTI — mutabakat tutarsa gecmis pozisyon metrikleri acilir"
