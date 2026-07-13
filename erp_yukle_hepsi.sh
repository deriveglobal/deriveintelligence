#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  6 YILIN TAMAMI — 2021..2026 satis faturalari
#
#    ./erp_yukle_hepsi.sh          # KURU CALISMA (hicbir sey yazmaz)
#    ./erp_yukle_hepsi.sh --yaz    # GERCEKTEN YAZ
#
#  Her yil AYRI islem: sil(takvim yili) + yaz + dogrula. Biri patlarsa
#  sadece o yil geri alinir, digerleri saglam kalir.
#
#  ⚠ ONCE deploy_lastik.sh CALISTIRILMIS OLMALI.
#     Aksi halde 5 yillik SERVIS satiri (İŞÇİLİK) urun master'a ve marka
#     analizine akar. 2026'da 17.000 satirdi; 6 yilda cok daha fazla.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd /opt/krb-assessment
YAZ="${1:-}"
shift 2>/dev/null || true
YILLAR="${*:-2021 2022 2023 2024 2025 2026}"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

# ── ON KOSUL: lastik filtresi yamali mi? ──
if ! grep -q "LASTIK_FILTRE_V1" server_container.mjs; then
  echo "❌ DUR. deploy_lastik.sh henuz calistirilmamis."
  echo "   Once onu calistir; yoksa 6 yillik servis verisi marka/ebat/urun"
  echo "   analizini bozar (İŞÇİLİK en cok satan marka olur)."
  exit 1
fi
echo "✅ LASTIK_FILTRE_V1 yamali."

echo
echo "════════════ ONCESI ════════════"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari WHERE tenant_id='$TEN'
 GROUP BY 1 ORDER BY 1;"

if [ "$YAZ" != "--yaz" ]; then
  echo
  echo "── YUKLENECEK CSV'LER ──"
  for Y in $YILLAR; do
    F="satis_${Y}_TEMIZ.csv"
    if [ -f "$F" ]; then printf "  %s  %8d satir\n" "$F" $(($(wc -l < "$F")-1))
    else echo "  ❌ $F YOK"; fi
  done
  echo
  echo "KURU CALISMA — hicbir sey yazilmadi."
  echo "Yazmak icin:  ./erp_yukle_hepsi.sh --yaz"
  exit 0
fi

DAMGA=$(date +%Y%m%d_%H%M%S)
echo
echo "════════════ TEK YEDEK (tum tablo) ════════════"
$PSQL -c "CREATE TABLE bi_satis_faturalari_yedek_${DAMGA} AS SELECT * FROM bi_satis_faturalari;" >/dev/null
echo "  bi_satis_faturalari_yedek_${DAMGA}"

BASARILI=0; BASARISIZ=""
for Y in $YILLAR; do
  F="satis_${Y}_TEMIZ.csv"
  [ -f "$F" ] || { echo "⏭  $Y atlandi (CSV yok)"; continue; }
  echo
  echo "════════════════ $Y ════════════════"
  tr -d '\r' < "$F" > /tmp/_y.csv
  KOL=$(head -1 /tmp/_y.csv)
  N=$(($(wc -l < /tmp/_y.csv)-1))
  docker cp /tmp/_y.csv krb-assessment-postgres:/tmp/_yukle.csv >/dev/null

  DENEME=0
  while :; do
  DENEME=$((DENEME+1))
  if $PSQL -v ON_ERROR_STOP=1 -v ten="$TEN" <<SQL
BEGIN;
CREATE TEMP TABLE _yeni (LIKE bi_satis_faturalari INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _yeni DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN export_date;
\copy _yeni ($KOL) FROM '/tmp/_yukle.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM bi_satis_faturalari
 WHERE tenant_id = :'ten'
   AND fatura_tarihi >= DATE '$Y-01-01'
   AND fatura_tarihi <  DATE '$((Y+1))-01-01';

INSERT INTO bi_satis_faturalari (tenant_id, export_date, $KOL)
SELECT :'ten', (SELECT max(fatura_tarihi) FROM _yeni), $KOL FROM _yeni;

DO \$\$
DECLARE g int; n int;
BEGIN
  SELECT count(*) FILTER (WHERE fatura_tarihi > CURRENT_DATE), count(*)
    INTO g, n FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '$Y-01-01'
     AND fatura_tarihi < DATE '$((Y+1))-01-01';
  IF g > 0  THEN RAISE EXCEPTION 'RED $Y: % gelecek tarihli', g; END IF;
  IF n <> $N THEN RAISE EXCEPTION 'RED $Y: % yazildi, % bekleniyordu', n, $N; END IF;
  RAISE NOTICE '✅ $Y: % satir', n;
END \$\$;

INSERT INTO bi_ingestion_log (tenant_id, query_type, export_date, row_count_raw,
                              row_count_kept, status, ingest_version, processed_at)
VALUES (:'ten', 'satis_faturalari', DATE '$Y-12-31', $N, $N, 'ok', 'erp_yukle_hepsi_v1', now());
COMMIT;
SQL
  then BASARILI=$((BASARILI+1)); break
  elif [ $DENEME -lt 3 ]; then
    echo "  ⚠ $Y basarisiz (deadlock olabilir) — ${DENEME}. deneme, 5sn sonra tekrar"
    sleep 5
  else
    BASARISIZ="$BASARISIZ $Y"; echo "  ❌ $Y BASARISIZ (3 denemede de) — o yil geri alindi"; break
  fi
  done
done

docker exec krb-assessment-postgres rm -f /tmp/_yukle.csv 2>/dev/null
$PSQL -c "DELETE FROM bi_morning_briefings WHERE tenant_id='$TEN';" >/dev/null

echo
echo "════════════ SONRASI ════════════"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL,
       count(*) FILTER (WHERE grup_adi LIKE 'LASTIK%') AS lastik_satir
  FROM bi_satis_faturalari WHERE tenant_id='$TEN'
 GROUP BY 1 ORDER BY 1;"
$PSQL -c "
SELECT count(*) FILTER (WHERE fatura_tarihi > CURRENT_DATE) AS gelecek_OLMALI_0,
       count(*) AS toplam FROM bi_satis_faturalari WHERE tenant_id='$TEN';"
echo "  -- Haziran 2026 = 121,76M olmali (Fatih Bilen'in SAP rakami) --"
$PSQL -c "
SELECT round(sum(satir_tutar)/1e6,2) AS haziran2026_MTL
  FROM bi_satis_faturalari WHERE tenant_id='$TEN'
   AND fatura_tarihi >= DATE '2026-06-01' AND fatura_tarihi < DATE '2026-07-01';"

echo
echo "basarili: $BASARILI yil   basarisiz:${BASARISIZ:- yok}"
echo "geri alma: DROP TABLE bi_satis_faturalari;"
echo "           ALTER TABLE bi_satis_faturalari_yedek_${DAMGA} RENAME TO bi_satis_faturalari;"
