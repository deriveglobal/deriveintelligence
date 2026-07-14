#!/usr/bin/env bash
# OLU_TABLO_ENVANTER — kesmeden once TAM ENVANTER. Sadece OKUR.
#
# ⚠ 4 OLU TABLO, 48 canli sorgu hala okuyor:
#     bi_stok_durumu · bi_musteri_bakiye · bi_odeme_gecmisi · bi_stok_hareketleri
#
# ⚠ VE BUGUN FARK ETTIGIM SEY IS I ACIL KILIYOR:
#   refreshSahaCariCache() — AZ ONCE zincire bagladigim fonksiyon —
#   bi_musteri_bakiye'den okuyor. O tablo OLU listesinde VE bozuk oldugunu
#   daha once tespit etmistik (566M vadesi gecmis / 11M bakiye).
#   Yani temsilcilerin musteri ARAMA KUTUSU, bozuk bir tablodan besleniyor olabilir.
#
# ⚠ CEO ASISTANI'nin SQL sablonlari da bu listede olabilir. Oyleyse Fatih Bilen'e
#   "gelir konusunda yalan soyledi" dedirten sey, terk edilmis bir tablodan gelen
#   bir sayi olabilir. Once BAKIYORUM, sonra konusuyorum.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
OLU="bi_stok_durumu bi_musteri_bakiye bi_odeme_gecmisi bi_stok_hareketleri"

echo "############ 1) OLU vs CANLI — hangisi gercekten olu? ############"
$PSQL -c "
SELECT c.relname AS tablo,
       to_char(c.reltuples::bigint, 'FM999,999,999') AS tahmini_satir,
       CASE WHEN c.relname IN ('bi_stok_durumu','bi_musteri_bakiye','bi_odeme_gecmisi','bi_stok_hareketleri')
            THEN '☠ OLU' ELSE '✓ canli' END AS sinif
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r'
   AND c.relname IN ('bi_stok_durumu','bi_stok_anlik',
                     'bi_musteri_bakiye','bi_cari_bakiye','master_musteri',
                     'bi_odeme_gecmisi',
                     'bi_stok_hareketleri','bi_stok_hareket')
 ORDER BY sinif DESC, c.relname;"

echo
echo "############ 2) OLU TABLOLAR — gercek satir sayisi + tazelik ############"
for T in $OLU; do
  VAR=$($PSQL -tAc "SELECT count(*) FROM information_schema.tables WHERE table_name='$T'")
  [ "$VAR" = "1" ] || { echo "  $T : TABLO YOK (zaten dusurulmus)"; continue; }
  N=$($PSQL -tAc "SELECT count(*) FROM $T" 2>/dev/null || echo "?")
  echo "  $T : $N satir"
done

echo
echo "############ 3) ⚠ KIM OKUYOR? — dosya dosya, satir satir ############"
for T in $OLU; do
  echo
  echo "  ══════ $T ══════"
  echo "  server_container.mjs :"
  grep -n "$T" server_container.mjs | grep -v "^.*//" | head -20
  C=$(grep -c "$T" server_container.mjs || true)
  echo "    toplam gecis: $C"
  echo "  diger dosyalar :"
  grep -rln "$T" --include=*.py --include=*.js --include=*.sql . 2>/dev/null \
    | grep -v "bak_\|srv_broken\|\.git" | head -5
done

echo
echo "############ 4) ⚠⚠ CEO ASISTANI — SQL sablonlari olu tablo iceriyor mu? ############"
echo "  (Fatih Bilen 11 Tem'de asistani birakti: 'gelir konusunda yalan soyledi')"
for T in $OLU; do
  echo "  --- $T, asistan sablonlarinda (25000-25500 arasi) ---"
  awk -v t="$T" 'NR>=24900 && NR<=25600 && index($0,t) { printf "%5d| %s\n", NR, substr($0,1,110) }' server_container.mjs
done
grep -n "sistem_prompt\|systemPrompt\|SQL_SABLON\|sql_template\|brain.*sql" server_container.mjs | head -8

echo
echo "############ 5) ⚠ refreshSahaCariCache — typeahead bozuk tablodan mi besleniyor? ############"
grep -n -A6 "async function refreshSahaCariCache" server_container.mjs | head -12
echo "  --- bi_musteri_bakiye gercekten bozuk mu? (566M vadesi gecmis / 11M bakiye iddiasi) ---"
$PSQL -c "
SELECT count(*) AS satir,
       count(DISTINCT musteri_kodu) AS musteri,
       max(export_date) AS son_export
  FROM bi_musteri_bakiye;" 2>/dev/null || echo "  (tablo okunamadi)"
