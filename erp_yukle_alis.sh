#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  ALIS (tedarikci) faturalari — 2021..2026
#    ./erp_yukle_alis.sh            # KURU CALISMA
#    ./erp_yukle_alis.sh --yaz      # YAZ (tum yillar)
#    ./erp_yukle_alis.sh --yaz 2025 # tek yil
#
#  ⚠ SATIS TABLOSUNDAN 2 FARK — ikisi de sessizce veri kaybettirir:
#    1) tenant_id UUID (satista TEXT).
#    2) FORCED ROW LEVEL SECURITY var. Oturumda app.current_tenant_id
#       ayarlanmazsa RLS politikasi INSERT'i REDDEDER ama hata vermeden
#       0 satir yazar. Bu yuzden her islemde SET LOCAL yapiyoruz VE
#       yazilan satiri sayip dogruluyoruz.
#
#  TURETILEN kolonlar (Excel'de YOK, DB'de VAR):
#    birim_fiyat_kdv_haric = Row Total / Quantity
#      ('Last Purchase Price' TUZAK: o kalemin en son alis fiyati, bu
#       faturanin degil. Sadece %39 tutuyor -> maliyet olarak KULLANILMAZ.)
#    vade_gun / vade_tarihi -> 'Payment Terms Code'tan turetildi.
#      Mevcut 28.252 satirin TAMAMINDA NULL'du: alis vadesi hic hesaplanmamis.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd /opt/krb-assessment
YAZ="${1:-}"
shift 2>/dev/null || true
YILLAR="${*:-2021 2022 2023 2024 2025 2026}"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "════════════ ONCESI ════════════"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil, count(*) AS satir,
       round(sum(satir_kdv_haric)/1e6,2) AS alis_MTL,
       count(*) FILTER (WHERE vade_tarihi IS NULL) AS vade_tarihi_NULL,
       count(*) FILTER (WHERE fatura_tarihi > CURRENT_DATE) AS gelecek_BOZUK
  FROM bi_tedarikci_faturalari WHERE tenant_id = '$TEN'::uuid
 GROUP BY 1 ORDER BY 1;"
echo "  ^ vade_tarihi_NULL = satirin tamami olmali (hic hesaplanmamis)."

if [ "$YAZ" != "--yaz" ]; then
  echo
  echo "── YUKLENECEK ──"
  for Y in $YILLAR; do
    F="alis_${Y}_TEMIZ.csv"
    if [ -f "$F" ]; then printf "  %-22s %7d satir\n" "$F" $(($(wc -l < "$F")-1))
    else echo "  ⏭  $F YOK (2022 dosyasi 2021 verisi iceriyordu — yeniden export lazim)"; fi
  done
  echo
  echo "KURU CALISMA — hicbir sey yazilmadi.   Yazmak icin: --yaz"
  exit 0
fi

DAMGA=$(date +%Y%m%d_%H%M%S)
echo
echo "════════ YEDEK ════════"
$PSQL -c "CREATE TABLE bi_tedarikci_faturalari_yedek_${DAMGA} AS SELECT * FROM bi_tedarikci_faturalari;" >/dev/null
echo "  bi_tedarikci_faturalari_yedek_${DAMGA}"

BASARILI=0; BASARISIZ=""
for Y in $YILLAR; do
  F="alis_${Y}_TEMIZ.csv"
  [ -f "$F" ] || { echo "⏭  $Y atlandi (CSV yok)"; continue; }
  echo
  echo "════════════════ $Y ════════════════"
  tr -d '\r' < "$F" > /tmp/_a.csv
  KOL=$(head -1 /tmp/_a.csv)
  N=$(($(wc -l < /tmp/_a.csv)-1))
  docker cp /tmp/_a.csv krb-assessment-postgres:/tmp/_alis.csv >/dev/null

  DENEME=0
  while :; do
  DENEME=$((DENEME+1))
  if $PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
-- ⚠ FORCED RLS: bu olmadan INSERT sessizce 0 satir yazar.
SET LOCAL app.current_tenant_id = '$TEN';

CREATE TEMP TABLE _yeni (LIKE bi_tedarikci_faturalari INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _yeni DROP COLUMN id, DROP COLUMN tenant_id,
                  DROP COLUMN export_date, DROP COLUMN ingested_at;

\copy _yeni ($KOL) FROM '/tmp/_alis.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM bi_tedarikci_faturalari
 WHERE tenant_id = '$TEN'::uuid
   AND fatura_tarihi >= DATE '$Y-01-01'
   AND fatura_tarihi <  DATE '$((Y+1))-01-01';

INSERT INTO bi_tedarikci_faturalari (tenant_id, export_date, $KOL)
SELECT '$TEN'::uuid, (SELECT max(fatura_tarihi) FROM _yeni), $KOL FROM _yeni;

DO \$\$
DECLARE g int; n int; v int;
BEGIN
  SELECT count(*) FILTER (WHERE fatura_tarihi > CURRENT_DATE),
         count(*),
         count(*) FILTER (WHERE vade_tarihi IS NOT NULL)
    INTO g, n, v
    FROM bi_tedarikci_faturalari
   WHERE tenant_id = '$TEN'::uuid
     AND fatura_tarihi >= DATE '$Y-01-01' AND fatura_tarihi < DATE '$((Y+1))-01-01';

  IF n = 0   THEN RAISE EXCEPTION 'RED $Y: 0 satir yazildi — RLS engellemis olabilir'; END IF;
  IF g > 0   THEN RAISE EXCEPTION 'RED $Y: % gelecek tarihli', g; END IF;
  IF n <> $N THEN RAISE EXCEPTION 'RED $Y: % yazildi, % bekleniyordu', n, $N; END IF;
  RAISE NOTICE '✅ $Y: % satir · % tanesinde vade_tarihi DOLU (once 0 idi)', n, v;
END \$\$;

INSERT INTO bi_ingestion_log (tenant_id, query_type, export_date, row_count_raw,
                              row_count_kept, status, ingest_version, processed_at)
VALUES ('$TEN', 'tedarikci_faturalari', DATE '$Y-12-31', $N, $N, 'ok', 'erp_yukle_alis_v1', now());
COMMIT;
SQL
  then BASARILI=$((BASARILI+1)); break
  elif [ $DENEME -lt 3 ]; then
    echo "  ⚠ $Y basarisiz — ${DENEME}. deneme, 5sn sonra tekrar"; sleep 5
  else
    BASARISIZ="$BASARISIZ $Y"; echo "  ❌ $Y BASARISIZ (geri alindi)"; break
  fi
  done
done

docker exec krb-assessment-postgres rm -f /tmp/_alis.csv 2>/dev/null

echo
echo "════════════ SONRASI ════════════"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil, count(*) AS satir,
       round(sum(satir_kdv_haric)/1e6,2) AS alis_MTL,
       round(sum(satir_kdv_haric) FILTER (WHERE grup_adi LIKE 'LASTIK%')/1e6,2) AS lastik_maliyet_MTL,
       count(*) FILTER (WHERE vade_tarihi IS NULL) AS vade_NULL,
       round(avg(vade_gun),1) AS ort_alis_vadesi_gun
  FROM bi_tedarikci_faturalari WHERE tenant_id = '$TEN'::uuid
 GROUP BY 1 ORDER BY 1;"
echo "  ^ ort_alis_vadesi_gun ARTIK HESAPLANABILIYOR — teklif onayinin"
echo "    'agirlikli ortalama alis vadesi' istegi bunu bekliyordu."

echo
echo "basarili: $BASARILI   basarisiz:${BASARISIZ:- yok}"
echo "geri alma: DROP TABLE bi_tedarikci_faturalari;"
echo "           ALTER TABLE bi_tedarikci_faturalari_yedek_${DAMGA} RENAME TO bi_tedarikci_faturalari;"
