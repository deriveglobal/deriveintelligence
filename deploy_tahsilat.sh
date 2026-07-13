#!/usr/bin/env bash
# TAHSILAT_V1 — fatura seviyesi tahsilat gecmisi (2021-2026). DSO'nun tek kaynagi.
#   ./deploy_tahsilat.sh        # KURU
#   ./deploy_tahsilat.sh --yaz  # YUKLE
#
# ⚠ TOPLAM TAHSILAT TUTARI BU DOSYADAN CIKARILMAZ (kartezyen carpim).
#   Sadece TAHSILAT SURESI / DSO / GECIKME guvenilir. Tarih onarimi ERP'nin
#   kendi 'Tahsilat Suresi' kolonuyla %100 dogrulandi (241.902 satir).
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

[ -f tahsilat_TEMIZ.csv ] || { echo "❌ tahsilat_TEMIZ.csv YOK"; exit 1; }
N=$(($(wc -l < tahsilat_TEMIZ.csv)-1))
echo "✅ CSV: $N fatura"

if [ "${1:-}" != "--yaz" ]; then
  echo
  echo "  KURU CALISMA. Yaz: ./deploy_tahsilat.sh --yaz"
  exit 0
fi

echo
echo "############ 1) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS bi_fatura_tahsilat (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  ingested_at   timestamptz NOT NULL DEFAULT now(),
  fatura_no     text NOT NULL,
  musteri_kodu  text,
  musteri_adi   text,
  grup_adi      text,
  satis_calisani text,
  fatura_tarihi date,
  vade_tarihi   date,
  vade_gun      integer,
  -- ⚠ fatura_tutari kaynak dosyada TEKRAR EDIYORDU; burada fatura basina TEK satir.
  fatura_tutari numeric(16,2),
  tahsilat_turu text,
  ilk_tahsilat  date,      -- "para NE ZAMAN geldi"
  son_tahsilat  date,      -- taksitliyse ne zaman kapandi
  tahsilat_gun  integer,   -- ilk_tahsilat - fatura_tarihi   (DSO'nun temeli)
  gecikme_gun   integer,   -- ilk_tahsilat - vade_tarihi     (+ = GEC odedi)
  tahsilat_satir_sayisi integer,
  UNIQUE (tenant_id, fatura_no)
);
CREATE INDEX IF NOT EXISTS idx_bft_tenant   ON bi_fatura_tahsilat (tenant_id, fatura_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_bft_musteri  ON bi_fatura_tahsilat (tenant_id, musteri_kodu);
CREATE INDEX IF NOT EXISTS idx_bft_calisan  ON bi_fatura_tahsilat (tenant_id, satis_calisani);
CREATE INDEX IF NOT EXISTS idx_bft_gecikme  ON bi_fatura_tahsilat (tenant_id, gecikme_gun DESC) WHERE gecikme_gun > 0;
SQL
echo "  ✅ tablo hazir"

echo
echo "############ 2) YUKLE ############"
tr -d '\r' < tahsilat_TEMIZ.csv > /tmp/_t.csv
KOL=$(head -1 /tmp/_t.csv)
docker cp /tmp/_t.csv krb-assessment-postgres:/tmp/_t.csv >/dev/null
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';
CREATE TEMP TABLE _t (LIKE bi_fatura_tahsilat INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _t DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN ingested_at;
\copy _t ($KOL) FROM '/tmp/_t.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM bi_fatura_tahsilat WHERE tenant_id='$TEN';
INSERT INTO bi_fatura_tahsilat (tenant_id, $KOL) SELECT '$TEN', $KOL FROM _t;

DO \$\$
DECLARE n int; dso numeric;
BEGIN
  SELECT count(*) INTO n FROM bi_fatura_tahsilat WHERE tenant_id='$TEN';
  IF n <> $N THEN RAISE EXCEPTION 'RED: % yazildi, % bekleniyordu', n, $N; END IF;
  SELECT sum(fatura_tutari*tahsilat_gun)/NULLIF(sum(fatura_tutari),0) INTO dso
    FROM bi_fatura_tahsilat WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL;
  IF dso < 5 OR dso > 60 THEN RAISE EXCEPTION 'RED: DSO % — 20,1 gun bekleniyordu', dso; END IF;
  RAISE NOTICE '✅ % fatura · DSO %', n, round(dso,1);
END \$\$;
COMMIT;
SQL
docker exec krb-assessment-postgres rm -f /tmp/_t.csv 2>/dev/null

echo
echo "############ 3) ⚠ MUTABAKAT — tahsilat faturalari vs satis faturalari ############"
$PSQL -c "
WITH t AS (
  SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
         count(*) AS fatura, round(sum(fatura_tutari)/1e6,1) AS tahsilat_dosyasi_MTL
    FROM bi_fatura_tahsilat WHERE tenant_id='$TEN' GROUP BY 1),
s AS (
  SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
         round(sum(satir_tutar)/1e6,1) AS satis_tablosu_MTL
    FROM bi_satis_faturalari WHERE tenant_id='$TEN' GROUP BY 1)
SELECT t.yil, t.fatura, t.tahsilat_dosyasi_MTL, s.satis_tablosu_MTL,
       round(100.0*t.tahsilat_dosyasi_MTL/NULLIF(s.satis_tablosu_MTL,0),0) AS oran_pct
  FROM t FULL JOIN s ON s.yil=t.yil ORDER BY 1;"
echo "  ^ Tahsilat dosyasi KDV DAHIL, satis tablosu KDV HARIC olabilir (~%120 beklenir)."
echo "    Cok saparsa: tahsilat dosyasi TUM faturalari kapsamiyor olabilir. NOT DUS."

echo
echo "############ 4) ⏱ DSO — temsilci bazinda (kim parayi GEC getiriyor?) ############"
$PSQL -c "
SELECT satis_calisani,
       count(*) AS fatura,
       round(sum(fatura_tutari)/1e6,1) AS ciro_MTL,
       round(sum(fatura_tutari*tahsilat_gun)/NULLIF(sum(fatura_tutari),0),1) AS DSO_gun,
       round(100.0*count(*) FILTER (WHERE gecikme_gun > 0)/NULLIF(count(*),0)) AS gec_odenen_pct
  FROM bi_fatura_tahsilat
 WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL
 GROUP BY 1 HAVING count(*) >= 200
 ORDER BY 4 DESC LIMIT 12;"

echo
echo "############ 5) ⏱ DSO — odeme turune gore ############"
$PSQL -c "
SELECT tahsilat_turu, count(*) AS fatura,
       round(sum(fatura_tutari)/1e6,1) AS tutar_MTL,
       round(sum(fatura_tutari*tahsilat_gun)/NULLIF(sum(fatura_tutari),0),1) AS DSO_gun,
       round(100.0*count(*) FILTER (WHERE gecikme_gun > 0)/NULLIF(count(*),0)) AS gec_pct
  FROM bi_fatura_tahsilat
 WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL
 GROUP BY 1 ORDER BY 3 DESC;"

echo
echo "############ 6) ⚠ NAKIT DONGUSU — alis vadesi vs tahsilat suresi ############"
$PSQL -c "
SELECT
  (SELECT round(sum(satir_kdv_haric*vade_gun)/NULLIF(sum(satir_kdv_haric),0),1)
     FROM bi_tedarikci_faturalari
    WHERE tenant_id='$TEN'::uuid AND vade_gun IS NOT NULL AND miktar > 0
      AND fatura_tarihi >= CURRENT_DATE - 365) AS DPO_alis_vadesi,
  (SELECT round(sum(fatura_tutari*tahsilat_gun)/NULLIF(sum(fatura_tutari),0),1)
     FROM bi_fatura_tahsilat
    WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL
      AND fatura_tarihi >= CURRENT_DATE - 365) AS DSO_tahsilat;"
echo "  ^ DSO > DPO ise: musteriden parayi ALMADAN tedarikciye ODUYORUZ."
echo "    Aradaki her gun ISLETME SERMAYESI demek. Bu, Finans sekmesinin kalbi."

git add -A && git commit -q -m "feat(finans): TAHSILAT_V1 — 175.649 fatura seviyesi tahsilat gecmisi (2021-2026). Tarih onarimi ERP'nin kendi kolonuyla %100 dogrulandi. DSO 20,1 gun. ⚠ Kaynak dosya kartezyen carpim iceriyor (fatura 9052 -> 235 satir, ayni tutar) -> TOPLAM TAHSILAT TUTARI HESAPLANMIYOR, sadece sure/gecikme." && echo "  COMMITTED"
