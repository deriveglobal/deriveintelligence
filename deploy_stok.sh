#!/usr/bin/env bash
# STOK_V1 — anlik stok + NAKIT DONGUSUNUN SON PARCASI (stok gunu / DIO)
#   ./deploy_stok.sh --yaz
#
# ⚠ Stok MALIYETI liste fiyatindan DEGIL, SON ALIS FIYATINDAN hesaplanir.
#   Liste ile degerleme maliyeti %40-50 sisirir -> stok gunu de sisir -> yanlis alarm.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
EXPORT="2026-07-12"

[ -f stok_TEMIZ.csv ] || { echo "❌ stok_TEMIZ.csv YOK"; exit 1; }
N=$(($(wc -l < stok_TEMIZ.csv)-1)); echo "✅ CSV: $N satir"
[ "${1:-}" = "--yaz" ] || { echo "  KURU. Yaz: ./deploy_stok.sh --yaz"; exit 0; }

echo
echo "############ 1) SEMA + YUKLE ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS bi_stok_anlik (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  export_date date NOT NULL,
  ingested_at timestamptz NOT NULL DEFAULT now(),
  depo text, kalem_kodu text NOT NULL, kalem_tanimi text, grup_adi text,
  marka text, sezon text, kategori2 text, kategori3 text,
  adet numeric(14,2), taahhut numeric(14,2), kullanilabilir numeric(14,2),
  -- ⚠ liste_fiyati MALIYET DEGIL. 55 satirda virgul bozuk -> NULL birakildi.
  liste_fiyati numeric(14,2),
  min_seviye numeric(14,2), max_seviye numeric(14,2)
);
CREATE INDEX IF NOT EXISTS idx_bsa ON bi_stok_anlik (tenant_id, export_date DESC, kalem_kodu);
CREATE INDEX IF NOT EXISTS idx_bsa_marka ON bi_stok_anlik (tenant_id, marka);
SQL
tr -d '\r' < stok_TEMIZ.csv > /tmp/_s.csv
KOL=$(head -1 /tmp/_s.csv)
docker cp /tmp/_s.csv krb-assessment-postgres:/tmp/_s.csv >/dev/null
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';
CREATE TEMP TABLE _s (LIKE bi_stok_anlik INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _s DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN export_date, DROP COLUMN ingested_at;
\copy _s ($KOL) FROM '/tmp/_s.csv' WITH (FORMAT csv, HEADER true)
DELETE FROM bi_stok_anlik WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT';
INSERT INTO bi_stok_anlik (tenant_id, export_date, $KOL) SELECT '$TEN', DATE '$EXPORT', $KOL FROM _s;
DO \$\$
DECLARE n int; a numeric;
BEGIN
  SELECT count(*), sum(adet) INTO n, a FROM bi_stok_anlik
   WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT';
  IF n <> $N THEN RAISE EXCEPTION 'RED: % yazildi, % bekleniyordu', n, $N; END IF;
  IF a < 10000 OR a > 200000 THEN RAISE EXCEPTION 'RED: toplam adet % — 52.295 bekleniyordu', a; END IF;
  RAISE NOTICE '✅ % satir · % adet lastik', n, a;
END \$\$;
COMMIT;
SQL
docker exec krb-assessment-postgres rm -f /tmp/_s.csv 2>/dev/null

echo
echo "############ 2) ⚠ MALIYET KAPSAMI — kac SKU'nun alis fiyati var? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN son.maliyet IS NOT NULL THEN '✅ maliyet VAR' ELSE '❌ maliyet YOK' END AS durum,
       count(*) AS sku, round(sum(s.adet)) AS adet,
       round(100.0*sum(s.adet)/sum(sum(s.adet)) OVER (),1) AS adet_pct
  FROM bi_stok_anlik s LEFT JOIN son ON son.kalem_kodu = s.kalem_kodu
 WHERE s.tenant_id='$TEN' AND s.export_date=DATE '$EXPORT'
 GROUP BY 1 ORDER BY 3 DESC;"
echo "  ^ '❌' orani buyukse stok degeri EKSIK hesaplanir -> stok gunu DUSUK cikar."

echo
echo "############ 3) 💰 STOK DEGERI (son alis maliyetiyle) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT s.depo, count(*) AS sku, round(sum(s.adet)) AS adet,
       round(sum(s.adet * son.maliyet)/1e6, 1) AS stok_degeri_MTL
  FROM bi_stok_anlik s JOIN son ON son.kalem_kodu = s.kalem_kodu
 WHERE s.tenant_id='$TEN' AND s.export_date=DATE '$EXPORT'
 GROUP BY 1 ORDER BY 4 DESC;"

echo
echo "############ 4) ⚠⚠ NAKIT DONGUSU — DENKLEM ARTIK TAM ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (
  SELECT sum(s.adet * son.maliyet) AS deger
    FROM bi_stok_anlik s JOIN son ON son.kalem_kodu = s.kalem_kodu
   WHERE s.tenant_id='$TEN' AND s.export_date=DATE '$EXPORT'),
smm AS (   -- son 365 gun SATILAN MALIN MALIYETI, AYNI maliyet temeliyle
  SELECT sum(f.miktar * son.maliyet) AS yillik
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.miktar > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 365),
dso AS (
  SELECT sum(fatura_tutari*tahsilat_gun)/NULLIF(sum(fatura_tutari),0) AS g
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL AND fatura_tarihi >= DATE '2026-01-01'),
dpo AS (
  SELECT sum(satir_kdv_haric*vade_gun)/NULLIF(sum(satir_kdv_haric),0) AS g
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND vade_gun IS NOT NULL AND miktar > 0
     AND fatura_tarihi >= DATE '2026-01-01'),
acik AS (
  SELECT sum(toplam_risk) AS r FROM bi_musteri_risk WHERE tenant_id='$TEN' AND musteri_mi),
sat AS (
  SELECT sum(fatura_tutari) t, sum(fatura_tutari*tahsilat_gun) a
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL AND fatura_tarihi >= DATE '2026-01-01')
SELECT round(stok.deger/1e6,1)                              AS stok_degeri_MTL,
       round(smm.yillik/1e6,1)                              AS yillik_SMM_MTL,
       round(stok.deger / NULLIF(smm.yillik/365,0), 1)      AS STOK_GUNU,
       round(dso.g,1)                                       AS DSO_gorunen,
       round((sat.a + acik.r*90)/NULLIF(sat.t + acik.r,0),1) AS DSO_gercekci,
       round(dpo.g,1)                                       AS DPO,
       round(stok.deger/NULLIF(smm.yillik/365,0) + dso.g - dpo.g, 1)  AS DONGU_iyimser,
       round(stok.deger/NULLIF(smm.yillik/365,0)
             + (sat.a + acik.r*90)/NULLIF(sat.t + acik.r,0) - dpo.g, 1) AS DONGU_gercekci
  FROM stok, smm, dso, dpo, acik, sat;"
echo
echo "  >>> NASIL OKUNUR:"
echo "      DONGU = STOK GUNU + DSO − DPO"
echo "      NEGATIF -> tedarikciye odemeden ONCE parayi aliyoruz. NAKIT URETIR."
echo "      POZITIF -> parayi almadan ONCE oduyoruz. Her gun ISLETME SERMAYESI yer."
echo "      'iyimser'   : acik alacaklar YOK sayilir (bugun ekranda gorunen)"
echo "      'gercekci'  : acik alacak (238,8M) 90 gunde tahsil edilir varsayimi"
echo "      ⚠ 'gercekci' bir TAHMIN, veri DEGIL. Ama yonu dogru."

echo
echo "############ 5) ⚠ OLU STOK — 365 gundur hic satilmamis ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT s.marka, count(*) AS sku, round(sum(s.adet)) AS adet,
       round(sum(s.adet*son.maliyet)/1e6,2) AS bagli_para_MTL
  FROM bi_stok_anlik s JOIN son ON son.kalem_kodu = s.kalem_kodu
 WHERE s.tenant_id='$TEN' AND s.export_date=DATE '$EXPORT' AND s.adet > 0
   AND NOT EXISTS (SELECT 1 FROM bi_satis_faturalari f
                    WHERE f.tenant_id='$TEN' AND f.kalem_kodu = s.kalem_kodu
                      AND f.fatura_tarihi >= CURRENT_DATE - 365 AND f.miktar > 0)
 GROUP BY 1 ORDER BY 4 DESC LIMIT 10;"
echo "  ^ Bu para RAFTA duruyor. Bir yildir tek adet satilmamis."

git add -A && git commit -q -m "feat(finans): STOK_V1 — 2.185 SKU / 52.295 lastik yuklendi. Stok degeri LISTE ile degil SON ALIS MALIYETI ile hesaplaniyor. Nakit dongusu denklemi TAMAMLANDI: stok gunu + DSO - DPO. Olu stok (365 gun satilmamis) marka bazinda cikarildi." && echo "  COMMITTED"
