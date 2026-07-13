#!/usr/bin/env bash
# RISK_V1 — accountriskreport -> bi_musteri_risk (+ odeme kirilimi)
#   ./deploy_risk.sh          # KURU: sema + mevcut durum, YAZMAZ
#   ./deploy_risk.sh --yaz    # tablolari kur ve YUKLE
#
# ⚠ ONCE risk_musteri_TEMIZ.csv ve risk_odeme_TEMIZ.csv scp'lenmis olmali.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
EXPORT="2026-07-12"

for f in risk_musteri_TEMIZ.csv risk_odeme_TEMIZ.csv; do
  [ -f "$f" ] || { echo "❌ $f YOK — once scp et"; exit 1; }
done
echo "✅ CSV'ler yerinde: $(($(wc -l < risk_musteri_TEMIZ.csv)-1)) muhatap · $(($(wc -l < risk_odeme_TEMIZ.csv)-1)) odeme satiri"

echo
echo "############ 1) ⚠ 663,48M NEREDEN GELIYOR? — mevcut rakami hesapla ############"
$PSQL -c "\d bi_musteri_bakiye" 2>/dev/null | head -14 || echo "  (tablo yok)"
$PSQL -c "
SELECT count(*) AS musteri,
       round(sum(vadesi_gecmis)/1e6,2) AS vadesi_gecmis_MTL
  FROM bi_musteri_bakiye WHERE tenant_id='$TEN';" 2>&1 | head -6
echo "  ^ Sistemin BUGUN gosterdigi rakam. Gercek: 145,4M (725 musteri)."
echo "    Fark ~4,6 kat. Bu sayi Fatih Bilen'in ekraninda DURUYOR."

if [ "${1:-}" != "--yaz" ]; then
  echo
  echo "  KURU CALISMA — hicbir sey yazilmadi.  Yaz:  ./deploy_risk.sh --yaz"
  exit 0
fi

echo
echo "############ 2) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS bi_musteri_risk (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  export_date         date NOT NULL,
  ingested_at         timestamptz NOT NULL DEFAULT now(),
  muhatap_kodu        text NOT NULL,
  muhatap_adi         text,
  vergi_no            text,
  vergi_dairesi       text,
  grup                text,
  -- ⚠ MUHATAP != MUSTERI. TEDARİKÇİ/PERSONEL/GRUP MUSTERILERI musteri DEGIL.
  --   BRISA'nin 18,7M vadesi gecmisi burada. Ciro raporuna KARISTIRMA.
  musteri_mi          boolean NOT NULL DEFAULT true,
  odeme_kosulu        text,
  satis_calisani      text,
  kredi_limiti        numeric(16,2),
  toplam_risk         numeric(16,2),
  -- ⚠ Odeme bicimine gore BOLUNMUS satirlarin TOPLAMI (detay: bi_musteri_risk_odeme)
  vadesi_gecmis       numeric(16,2),
  limit_asimi         numeric(16,2),
  hesap_bakiyesi      numeric(16,2),
  cek_senet_riski     numeric(16,2),
  kullanilabilir_limit numeric(16,2),
  taahhut_limiti      numeric(16,2),
  dbs_limit           numeric(16,2),
  odenmemis_cekler    numeric(16,2),
  odenmemis_senetler  numeric(16,2),
  bekleyen_siparis    numeric(16,2),
  ciro_2019           numeric(16,2),
  ciro_2020           numeric(16,2),
  ciro_2021           numeric(16,2),
  UNIQUE (tenant_id, export_date, muhatap_kodu)
);
CREATE INDEX IF NOT EXISTS idx_bmr_tenant   ON bi_musteri_risk (tenant_id, export_date DESC);
CREATE INDEX IF NOT EXISTS idx_bmr_asim     ON bi_musteri_risk (tenant_id, limit_asimi DESC) WHERE limit_asimi > 0;
CREATE INDEX IF NOT EXISTS idx_bmr_vg       ON bi_musteri_risk (tenant_id, vadesi_gecmis DESC) WHERE vadesi_gecmis > 0;
CREATE INDEX IF NOT EXISTS idx_bmr_calisan  ON bi_musteri_risk (tenant_id, satis_calisani);
CREATE INDEX IF NOT EXISTS idx_bmr_kod      ON bi_musteri_risk (tenant_id, muhatap_kodu);

CREATE TABLE IF NOT EXISTS bi_musteri_risk_odeme (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  export_date      date NOT NULL,
  muhatap_kodu     text NOT NULL,
  odeme_bicimi     text NOT NULL,
  vadesi_gecmis    numeric(16,2),
  ort_tahsilat_gun numeric(10,2)
);
CREATE INDEX IF NOT EXISTS idx_bmro ON bi_musteri_risk_odeme (tenant_id, muhatap_kodu, export_date DESC);
SQL
echo "  ✅ tablolar hazir"

echo
echo "############ 3) YUKLE (islem icinde, aralik-degistir) ############"
tr -d '\r' < risk_musteri_TEMIZ.csv > /tmp/_rm.csv
tr -d '\r' < risk_odeme_TEMIZ.csv   > /tmp/_ro.csv
KM=$(head -1 /tmp/_rm.csv); KO=$(head -1 /tmp/_ro.csv)
NM=$(($(wc -l < /tmp/_rm.csv)-1)); NO=$(($(wc -l < /tmp/_ro.csv)-1))
docker cp /tmp/_rm.csv krb-assessment-postgres:/tmp/_rm.csv >/dev/null
docker cp /tmp/_ro.csv krb-assessment-postgres:/tmp/_ro.csv >/dev/null

$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';   -- RLS acilirsa diye

CREATE TEMP TABLE _m (LIKE bi_musteri_risk INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _m DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN export_date,
               DROP COLUMN ingested_at;
\copy _m ($KM) FROM '/tmp/_rm.csv' WITH (FORMAT csv, HEADER true)

CREATE TEMP TABLE _o (LIKE bi_musteri_risk_odeme INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _o DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN export_date;
\copy _o ($KO) FROM '/tmp/_ro.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM bi_musteri_risk        WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT';
DELETE FROM bi_musteri_risk_odeme  WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT';

INSERT INTO bi_musteri_risk (tenant_id, export_date, $KM)
SELECT '$TEN', DATE '$EXPORT', $KM FROM _m;
INSERT INTO bi_musteri_risk_odeme (tenant_id, export_date, $KO)
SELECT '$TEN', DATE '$EXPORT', $KO FROM _o;

DO \$\$
DECLARE nm int; no_ int; vg numeric;
BEGIN
  SELECT count(*) INTO nm FROM bi_musteri_risk WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT';
  SELECT count(*) INTO no_ FROM bi_musteri_risk_odeme WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT';
  IF nm <> $NM THEN RAISE EXCEPTION 'RED: musteri % yazildi, % bekleniyordu', nm, $NM; END IF;
  IF no_ <> $NO THEN RAISE EXCEPTION 'RED: odeme % yazildi, % bekleniyordu', no_, $NO; END IF;
  SELECT sum(vadesi_gecmis) INTO vg FROM bi_musteri_risk
   WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT' AND musteri_mi;
  IF vg < 140e6 OR vg > 150e6 THEN
    RAISE EXCEPTION 'RED: musteri vadesi gecmis % — 145,4M bekleniyordu', vg;
  END IF;
  RAISE NOTICE '✅ % muhatap · % odeme satiri · musteri vadesi gecmis %M', nm, no_, round(vg/1e6,1);
END \$\$;
COMMIT;
SQL
docker exec krb-assessment-postgres rm -f /tmp/_rm.csv /tmp/_ro.csv 2>/dev/null

echo
echo "############ 4) ⚠ KREDI KONTROL — LIMIT ASAN MUSTERILER (temsilci bazinda) ############"
$PSQL -c "
SELECT satis_calisani,
       count(*) AS limit_asan_musteri,
       round(sum(limit_asimi)/1e6,2) AS toplam_asim_MTL,
       round(sum(vadesi_gecmis)/1e6,2) AS vadesi_gecmis_MTL
  FROM bi_musteri_risk
 WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT'
   AND musteri_mi AND limit_asimi > 0
 GROUP BY 1 ORDER BY 3 DESC;"

echo
echo "############ 5) EN RISKLI 12 MUSTERI ############"
$PSQL -c "
SELECT left(muhatap_adi,32) AS musteri, grup, satis_calisani,
       round(kredi_limiti) AS limit_TL, round(toplam_risk) AS risk_TL,
       round(limit_asimi) AS asim_TL, round(vadesi_gecmis) AS vadesi_gecmis_TL
  FROM bi_musteri_risk
 WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT' AND musteri_mi
 ORDER BY limit_asimi DESC NULLS LAST LIMIT 12;"

echo
echo "############ 6) ⚠ MUSTERI DEGIL — tedarikci/personel/grup (ciroya KARISTIRMA) ############"
$PSQL -c "
SELECT grup, count(*) AS muhatap,
       round(sum(vadesi_gecmis)/1e6,2) AS vadesi_gecmis_MTL,
       round(sum(toplam_risk)/1e6,2) AS risk_MTL
  FROM bi_musteri_risk
 WHERE tenant_id='$TEN' AND export_date=DATE '$EXPORT' AND NOT musteri_mi
 GROUP BY 1 ORDER BY 3 DESC;"
echo "  ^ BRISA'nin vadesi gecmisi burada — bu bir MUSTERI ALACAGI DEGIL."

echo
echo "############ 7) ODEME BICIMI KIRILIMI — tahsilat suresi ############"
$PSQL -c "
SELECT o.odeme_bicimi, count(*) AS satir,
       round(sum(o.vadesi_gecmis)/1e6,2) AS vadesi_gecmis_MTL,
       round(avg(NULLIF(o.ort_tahsilat_gun,0))::numeric,1) AS ort_tahsilat_gun
  FROM bi_musteri_risk_odeme o
  JOIN bi_musteri_risk m ON m.tenant_id=o.tenant_id AND m.muhatap_kodu=o.muhatap_kodu
                        AND m.export_date=o.export_date
 WHERE o.tenant_id='$TEN' AND o.export_date=DATE '$EXPORT' AND m.musteri_mi
 GROUP BY 1 ORDER BY 3 DESC;"
echo "  ^ Hangi odeme bicimi PARAYI GEC getiriyor? Vade politikasi burada."

git add -A && git commit -q -m "feat(risk): RISK_V1 — accountriskreport yuklendi. 48.416 satir -> 38.604 muhatap. Iki farkli satir mantigi: musteri seviyesi alanlar tekrar eder (tekillestir), vadesi gecmis odeme bicimine gore bolunur (topla). Musteri vadesi gecmis = 145,4M / 725 musteri (sistem 663,48M gosteriyordu). 165 musteri kredi limitini asmis. Tedarikci/personel/grup 'musteri_mi=false' ile ayrildi -- BRISA'nin 18,7M'i musteri alacagi DEGIL." && echo "  COMMITTED"
