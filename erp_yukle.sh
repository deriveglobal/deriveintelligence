#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  erp_yukle.sh — TEMIZ CSV -> Postgres. ARALIK DEGISTIRME. Tek islem.
#
#    ./erp_yukle.sh satis_TEMIZ.csv          # KURU CALISMA (hicbir sey yazmaz)
#    ./erp_yukle.sh satis_TEMIZ.csv --yaz    # GERCEKTEN YAZ
#
#  1) tabloyu YEDEKLER
#  2) TEK ISLEM: CSV araligindaki eski satirlari SIL -> CSV'yi YAZ -> DOGRULA
#  3) dogrulama gecmezse ROLLBACK. Tablo hic dokunulmamis gibi kalir.
#
#  Neden aralik-degistirme: Haziran dosyasi 01.01-12.06'yi, yeni dosya
#  01.01-11.07'yi kapsiyor. Duz INSERT olsa Ocak-Haziran IKINCI KEZ girer,
#  ciro iki katina cikardi. Aralik silinip yeniden yazilinca bu IMKANSIZ.
#
#  Gecmis ders: CSV'de \r vardi (python csv varsayilani \r\n) ve kolon
#  listesini bozdu. Artik hem uretimde hem burada temizleniyor.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

CSV="${1:-satis_TEMIZ.csv}"
YAZ="${2:-}"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
TABLO="bi_satis_faturalari"
TK="fatura_tarihi"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
DAMGA=$(date +%Y%m%d_%H%M%S)

[ -f "$CSV" ] || { echo "❌ CSV yok: $CSV"; exit 1; }

# ── \r temizligi (savunma) ──
if grep -q $'\r' "$CSV"; then
  echo "⚠ CSV'de CR bulundu, temizleniyor..."
  tr -d '\r' < "$CSV" > "${CSV}.tmp" && mv "${CSV}.tmp" "$CSV"
fi

KOL=$(head -1 "$CSV")
SATIR=$(($(wc -l < "$CSV") - 1))
# ⚠ 'sort | head -1' KULLANMA: head boruyu erken kapatir -> sort SIGPIPE (141)
#   -> pipefail + set -e  -> script HIC CIKTI VERMEDEN oluyordu. Tek gecis awk:
read -r ILK SON < <(awk -F, 'NR>1 && $1!="" {
      if (min == "" || $1 < min) min = $1
      if ($1 > max) max = $1
    } END { print min, max }' "$CSV")
[ -n "$ILK" ] && [ -n "$SON" ] || { echo "❌ CSV'den tarih araligi okunamadi"; exit 1; }

# ⚠⚠ SILME ARALIGI = TAKVIM YILI, dosyanin min/max'i DEGIL.
#   Sebep: DB'deki bozuk satirlarin AYI yanlis ama YILI dogru (takas ay<->gun,
#   yili degistirmez). Dosya 02.01-11.07 diyor; ama DB'de ayni faturalarin
#   1.419 tanesi Agustos-Aralik 2026'ya dusmus durumda. min/max ile silseydik
#   o 1.419 satir SAG KALIR ve duzeltilmis kopyalariyla birlikte MUKERRER olurdu.
#   Bunu kuru calisma yakaladi: silinecek=5.777 ama 2026'da 7.196 satir var.
YIL_BAS="${ILK:0:4}-01-01"
YIL_SON="$(( ${SON:0:4} + 1 ))-01-01"

echo "═══════════════════════════════════════════════════════════"
echo "  tablo  : $TABLO"
echo "  csv    : $CSV   ($SATIR satir)"
echo "  dosya  : $ILK .. $SON"
echo "  silme  : $YIL_BAS .. $YIL_SON (TAKVIM YILI — bozuk tarihler Agu-Ara'ya dusmus)"
echo "  mod    : $([ "$YAZ" = "--yaz" ] && echo '⚠⚠ YAZMA MODU' || echo 'KURU CALISMA')"
echo "═══════════════════════════════════════════════════════════"

echo
echo "── SIMDIKI DURUM ──"
$PSQL -c "
SELECT count(*)                                                          AS toplam,
       count(*) FILTER (WHERE $TK >= DATE '$YIL_BAS' AND $TK < DATE '$YIL_SON') AS silinecek,
       count(*) FILTER (WHERE $TK > CURRENT_DATE)                        AS gelecek_BOZUK,
       count(*) FILTER (WHERE vade_tarihi < fatura_tarihi)               AS ters_BOZUK,
       round(sum(satir_tutar) FILTER (WHERE $TK >= DATE '2026-01-01')/1e6,2) AS ciro2026_MTL
  FROM $TABLO WHERE tenant_id = '$TEN';"
echo "  yazilacak: $SATIR satir"

if [ "$YAZ" != "--yaz" ]; then
  echo
  echo "KURU CALISMA — hicbir sey yazilmadi."
  echo "Yazmak icin:  ./erp_yukle.sh $CSV --yaz"
  exit 0
fi

echo
echo "── 1) YEDEK ──"
$PSQL -c "CREATE TABLE ${TABLO}_yedek_${DAMGA} AS SELECT * FROM $TABLO;" >/dev/null
echo "   ${TABLO}_yedek_${DAMGA}"

echo
echo "── 2) CSV'yi container'a kopyala ──"
# ⚠ DERS: CSV'yi psql'in STDIN'ine BORULAYAMAYIZ -- SQL de heredoc ile STDIN'den
#   geliyor. Ikisi ayni akisi paylasamaz; '\copy FROM STDIN' heredoc'u okuyup
#   "missing data for column vade_tarihi" ile patliyordu. Cozum: dosyayi
#   container'in icine koy, \copy oradan OKUSUN. STDIN sadece SQL'e kalsin.
docker cp "$CSV" krb-assessment-postgres:/tmp/_yukle.csv
echo "   -> /tmp/_yukle.csv"

echo
echo "── 3) TEK ISLEM: SIL + YAZ + DOGRULA ──"
$PSQL -v ON_ERROR_STOP=1 -v ten="$TEN" <<SQL
BEGIN;

-- Gercek semadan tureyen gecici tablo (sed yok, tahmin yok)
CREATE TEMP TABLE _yeni (LIKE $TABLO INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _yeni DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN export_date;

\copy _yeni ($KOL) FROM '/tmp/_yukle.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM $TABLO
 WHERE tenant_id = :'ten'
   AND $TK >= DATE '$YIL_BAS' AND $TK < DATE '$YIL_SON';

INSERT INTO $TABLO (tenant_id, export_date, $KOL)
SELECT :'ten', DATE '$SON', $KOL FROM _yeni;

-- ── KABUL KAPISI — gecmezse ROLLBACK ──
DO \$\$
DECLARE g int; t int; n int;
BEGIN
  SELECT count(*) FILTER (WHERE fatura_tarihi > CURRENT_DATE),
         count(*) FILTER (WHERE vade_tarihi < fatura_tarihi),
         count(*)
    INTO g, t, n
    FROM $TABLO
   WHERE tenant_id = '$TEN' AND $TK >= DATE '$YIL_BAS' AND $TK < DATE '$YIL_SON';

  IF g > 0      THEN RAISE EXCEPTION 'RED: % gelecek tarihli fatura', g; END IF;
  IF t > 0      THEN RAISE EXCEPTION 'RED: % ters vade (vade < fatura)', t; END IF;
  IF n <> $SATIR THEN RAISE EXCEPTION 'RED: % satir yazildi, % bekleniyordu', n, $SATIR; END IF;
  RAISE NOTICE '✅ KAPI GECILDI: % satir · 0 gelecek · 0 ters vade', n;
END \$\$;

INSERT INTO bi_ingestion_log (tenant_id, query_type, export_date, row_count_raw,
                              row_count_kept, status, ingest_version, processed_at)
VALUES (:'ten', 'satis_faturalari', DATE '$SON', $SATIR, $SATIR, 'ok', 'erp_yukle_v1', now());

DELETE FROM bi_morning_briefings WHERE tenant_id = :'ten' AND briefing_date = CURRENT_DATE;

COMMIT;
SQL

echo
echo "── 4) SONUC: 2026 ay dagilimi ──"
$PSQL -c "
SELECT to_char($TK,'YYYY-MM') AS ay, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM $TABLO WHERE tenant_id='$TEN' AND $TK >= DATE '2026-01-01'
 GROUP BY 1 ORDER BY 1;"
$PSQL -c "
SELECT count(*) FILTER (WHERE $TK > CURRENT_DATE)           AS gelecek_OLMALI_0,
       count(*) FILTER (WHERE vade_tarihi < fatura_tarihi)  AS ters_OLMALI_0,
       count(*)                                             AS toplam
  FROM $TABLO WHERE tenant_id='$TEN';"

docker exec krb-assessment-postgres rm -f /tmp/_yukle.csv

echo
echo "✅ BITTI. Geri almak icin:"
echo "   docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \\"
echo "     \"DROP TABLE $TABLO; ALTER TABLE ${TABLO}_yedek_${DAMGA} RENAME TO $TABLO;\""
