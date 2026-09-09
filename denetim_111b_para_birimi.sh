#!/usr/bin/env bash
# DENETIM_111B — para_birimi TL/TRY: YAZIM NOKTASINI bul, veriyi normalize et.
#   ⚠ Once INSERT nerede — onu gormeden kod yamalamam. Bu adim: kesif + VERI normalize.
#   Kod yamasi (yazimda normalize) ANKRAJ gorulunce ayri adimda.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SRC="server_container.mjs"

echo "############ 1) bi_fiyat_listesi_kalemler'e para_birimi NEREDE yaziliyor? ############"
grep -nE "INSERT INTO bi_fiyat_listesi_kalemler|bi_fiyat_listesi_kalemler.*VALUES|para_birimi" "$SRC" \
  | grep -iE "insert|values|para_birimi" | head -20 | sed 's/^/  /'
echo "  --- fiyat listesi YUKLEME handler'i (upload) ---"
grep -nE "fiyat-listesi|price-list.*upload|bi_fiyat_listesi_uploads|listeYukle|fiyatListesiYukle" "$SRC" | head -15 | sed 's/^/  /'

echo
echo "############ 2) INSERT'in tam govdesi (para_birimi kolonu nasil dolduruluyor) ############"
LN=$(grep -nE "INSERT INTO bi_fiyat_listesi_kalemler" "$SRC" | head -1 | cut -d: -f1)
if [ -n "${LN:-}" ]; then
  echo "  INSERT satiri: $LN"
  sed -n "$((LN-2)),$((LN+25))p" "$SRC" | nl -ba -v$((LN-2)) | sed 's/^/  /'
else
  echo "  ⚠ Dogrudan INSERT bulunamadi — COPY ya da parametreli olabilir. para_birimi gecen blok:"
  grep -nE "para_birimi" "$SRC" | sed 's/^/  /'
fi

echo
echo "############ 3) ONCE — mevcut dagilim ############"
$PSQL -c "SELECT para_birimi, count(*) FROM bi_fiyat_listesi_kalemler GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 4) VERI NORMALIZE — TL/₺/tl -> TRY (yedekli) ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- ⚠ yedek: sadece etiket degisecek satirlar
DROP TABLE IF EXISTS yedek_para_birimi;
CREATE TABLE yedek_para_birimi AS
  SELECT id, para_birimi FROM bi_fiyat_listesi_kalemler
   WHERE upper(trim(coalesce(para_birimi,''))) IN ('TL','₺','TL.','TRL');
UPDATE bi_fiyat_listesi_kalemler
   SET para_birimi = 'TRY'
 WHERE upper(trim(coalesce(para_birimi,''))) IN ('TL','₺','TL.','TRL');
SQL
echo "  ✅ TL -> TRY (yedek: yedek_para_birimi)"

echo
echo "############ 5) SONRA — tek etiket mi? ############"
$PSQL -c "SELECT para_birimi, count(*) FROM bi_fiyat_listesi_kalemler GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Tek satir (TRY) kalmali. Boş/NULL varsa ayri mesele — rapor eder."
$PSQL -c "SELECT count(*) AS bos_para FROM bi_fiyat_listesi_kalemler WHERE para_birimi IS NULL OR trim(para_birimi)='';"

echo
echo "############ SONUC ############"
echo "  ✅ Mevcut veri tek etikete indi (TRY)."
echo "  ⚠ SONRAKI: yazim noktasi (yukarida) normalize edilmeli — yoksa yeni yukleme yine boler."
echo "     Ankraj gorunduyse bir sonraki adimda kodu yamalarim; gorunmediyse COPY/ingest yolu incelenir."
