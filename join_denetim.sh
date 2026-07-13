#!/usr/bin/env bash
# ⚠ CANLIDA HANGI SORGULAR BOZUK JOIN KULLANIYOR?
#   Bulunan 3 hata (#12 bos bayi_fiyati, #13 tesvik marka case, #14 ebat format)
#   BENIM kupumun degil, MEVCUT SISTEMIN de hatasi. Fatih Bilen ve 8 saha temsilcisi
#   PAZARTESI bunu gorecek. Once burayi onarmak lazim, kup bekleyebilir.
#
#   YAMA YOK. SADECE BAKIYORUZ. Ne kirdigimizi bilmeden dokunmuyoruz.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) bi_fiyat_listesi_kalemler'i KIM okuyor? ############"
grep -n "bi_fiyat_listesi_kalemler" server_container.mjs | head -30

echo
echo "############ 2) ⚠ BOS KOLONLARI okuyan var mi? (bayi_fiyati / net_fiyati) ############"
echo "   -- 19 listenin HEPSINDE bu iki kolon BOS. Okuyan sorgu NULL doner. --"
grep -n "bayi_fiyati\|net_fiyati" server_container.mjs | head -20

echo
echo "############ 3) ⚠ TESVIK JOIN — marka case duyarli mi? ############"
grep -n "bi_tedarikci_tesvik" server_container.mjs | head -20

echo
echo "############ 4) ⚠ EBAT JOIN — ham mi, normalize mi? ############"
grep -n "k.ebat *=\|\.ebat *= *\$\|ebat *= *f\.ebat\|ON .*ebat" server_container.mjs | head -20

echo
echo "############ 5) SAHA tarafi — temsilci fiyat sorgusu ############"
grep -n "bi_fiyat_listesi\|liste_fiyati" shells/saha.js | head -12

echo
echo "############ 6) ⚠⚠ CANLI ENDPOINT NE DONUYOR? — gercek istekle test ############"
echo "   (fiyat/marj endpointleri; token gerekiyorsa 401 doner, o zaman SQL ile test)"
for E in /api/bi/pricing/liste /api/bi/pricing/marj /api/bi/fiyat/ara; do
  printf "  %-28s -> HTTP %s\n" "$E" "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080$E?ebat=205/55R16&marka=BRIDGESTONE")"
done

echo
echo "############ 7) ⚠⚠ ETKI OLCUMU — mevcut join ne kadarini kaciriyor? ############"
$PSQL <<SQL
SET app.current_tenant_id = '$TEN';
\echo '--- Bir saha temsilcisi 205/55R16 BRIDGESTONE sorarsa BUGUN ne olur? ---'
\echo '  (a) MEVCUT: ham ebat + case duyarli marka'
SELECT count(*) AS bulunan_satir, max(k.liste_fiyati) AS liste, max(k.bayi_fiyati) AS bayi_BOS
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
 WHERE u.tenant_id='$TEN'::uuid AND u.marka='BRIDGESTONE' AND k.ebat='205/55R16';

\echo '  (b) NORMALIZE: bi_ebat_norm + upper(marka)'
SELECT count(*) AS bulunan_satir, max(k.liste_fiyati) AS liste, max(k.desen) AS desen
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
 WHERE u.tenant_id='$TEN'::uuid AND upper(u.marka)='BRIDGESTONE'
   AND bi_ebat_norm(k.ebat)=bi_ebat_norm('205/55R16');

\echo ''
\echo '--- ⚠ TUM LISTE: kac ebat BUGUN bulunamiyor, normalize edilince bulunuyor? ---'
WITH ham AS (SELECT DISTINCT u.marka, k.ebat FROM bi_fiyat_listesi_kalemler k
               JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
              WHERE u.tenant_id='$TEN'::uuid),
     satis AS (SELECT DISTINCT marka, ebat FROM bi_satis_faturalari
                WHERE tenant_id='$TEN' AND ebat IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365)
SELECT (SELECT count(*) FROM satis s JOIN ham h ON h.marka=s.marka AND h.ebat=s.ebat)          AS BUGUN_BULUNAN,
       (SELECT count(*) FROM satis s JOIN ham h ON upper(h.marka)=upper(s.marka)
          AND bi_ebat_norm(h.ebat)=bi_ebat_norm(s.ebat))                                       AS NORMALIZE_BULUNAN;

\echo ''
\echo '--- ⚠⚠ TESVIK: bugun uygulaniyor mu? ---'
SELECT 'MEVCUT (case duyarli)' AS yontem, count(*) AS eslesen
  FROM bi_fiyat_listesi_uploads u JOIN bi_tedarikci_tesvik t
    ON t.marka=u.marka AND t.tenant_id=u.tenant_id
 WHERE u.tenant_id='$TEN'::uuid
UNION ALL
SELECT 'upper() ile', count(*)
  FROM bi_fiyat_listesi_uploads u JOIN bi_tedarikci_tesvik t
    ON upper(t.marka)=upper(u.marka) AND t.tenant_id=u.tenant_id
 WHERE u.tenant_id='$TEN'::uuid;
SQL
