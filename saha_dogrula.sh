#!/usr/bin/env bash
# SAHA_DOGRULA — "kodda 403 kalmadi" KANIT DEGIL, sadece gosterge.
# Gercek istegi ATIP gorecegim. Eftal'e bir sey gondermeden once.
#
# ⚠ IKI YANLISIMI DUZELTIYORUM:
#   1. TUKETICI/TICARI musteri tipi DEGIL, LASTIK GRUBU (binek / ticari-TBR).
#      "ER OTO LASTIK"in TUKETICI olmasi DOGRU. Ben ikinci bir hata icat etmisim.
#      Kodun mantigi tutarli: sektorler+tedarikci_markalar sadece TICARI'da (saha.js:1002),
#      durum sadece TUKETICI'de (saha.js:1252) gonderiliyor. Simetrik, kasitli.
#   2. Bu yuzden gercek kayip DAHA DAR:
#        12 binek musterisi  -> durum
#         1 ticari (KRB MERKEZ) -> sektorler + tedarikci_markalar
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) KONTEYNER GERCEKTEN YENI KODU MU SERVIS EDIYOR? ############"
for f in server.mjs shells/saha.js; do
  R=$(md5sum "$(echo $f | sed 's|^server.mjs$|server_container.mjs|')" 2>/dev/null | cut -c1-32)
  C=$(docker exec krb-assessment md5sum /app/$f 2>/dev/null | cut -c1-32)
  [ "$R" = "$C" ] && echo "  ✅ $f  repo = konteyner" || echo "  ❌ $f  SAPMA  repo=$R konteyner=$C"
done
echo "  --- konteynerde 403 kapisi kaldi mi? ---"
docker exec krb-assessment sh -c 'grep -c "Bu müşteri size atanmamış" /app/server.mjs || true' | sed 's/^/      adet: /'

echo
echo "############ 2) OTURUM MEKANIZMASI — gercek istek icin ############"
$PSQL -c "SELECT table_name FROM information_schema.tables
          WHERE table_name ILIKE '%session%' OR table_name ILIKE '%token%';"
T=$($PSQL -tAc "SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%session%' LIMIT 1")
if [ -n "$T" ]; then
  echo "  --- $T sutunlari ---"
  $PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='$T' ORDER BY ordinal_position;"
fi
echo "  --- sunucu oturumu nasil okuyor? (cookie adi) ---"
grep -on "cookie[^;]\{0,60\}" server_container.mjs | grep -i "sid\|token\|session" | head -5
grep -n "function requireSession\|async function requireSession\|readSession\|getSession" server_container.mjs | head -5

echo
echo "############ 3) ⚠ KAYIP VERININ TAM ENVANTERI (dar hali) ############"
$PSQL -c "
SELECT mu.tip,
       count(*) AS musteri,
       string_agg(DISTINCT mu.durum, ', ') AS simdiki_durum
  FROM saha_hata_log h
  JOIN saha_musteri mu ON mu.id = replace(h.endpoint,'/api/saha/musteriler/','')::uuid
 WHERE h.user_id='ae0c55f9-68cc-421d-96d9-409222452f1a'
   AND h.http_status=403 AND h.ts >= current_date - 1
 GROUP BY mu.tip;
"
echo "  (TUKETICI = binek grubu -> kaybolan alan: durum)"
echo "  (TICARI   = ticari grup -> kaybolan alan: sektorler + tedarikci_markalar)"

echo
echo "############ 4) AYNI HATA BASKA KIMDE VAR? (sadece Eftal mi?) ############"
$PSQL -c "
SELECT u.full_name, u.email, count(*) AS hata, min(h.ts)::date AS ilk, max(h.ts)::date AS son
  FROM saha_hata_log h JOIN users u ON u.id = h.user_id
 WHERE h.hata_mesaji = 'Bu müşteri size atanmamış.'
 GROUP BY 1,2 ORDER BY hata DESC;
"
echo "  ⚠ Bu kapi NE ZAMANDAN BERI acik? Eftal ilk kurban degilse, kayip 13'ten buyuk."
