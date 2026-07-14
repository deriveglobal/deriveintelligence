#!/usr/bin/env bash
# FORM_HATIRLAMA_KESIF — ziyaret formu musteriyi hatirlamiyor.
#   c4ff0c93 (Eftal): vkn, tc, yetkili, cep telefonu otomatik gelsin
#   56dd9899 (Huseyin): sektor, arac parki, markalar, tedarikci, yillik potansiyel
#                       onceki ziyaretten SECILI gelsin
#
# ⚠ Bugun 403 kapisi kalkti -> veri artik KAYDEDILIYOR.
#   Hatirlayamamasinin sebebi unutkanlik degil, KAYDEDEMEMESIYDI.
#   Simdi yaziliyor; geriye formu acarken GERI OKUMAK kaldi.
#
# ⚠ Once eslesmeyi gorecegim: form hangi alanlari topluyor, musteride
#   hangilerinin KARSILIGI VAR, hangisinin YOK.
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) saha_musteri — hangi alanlar SAKLANIYOR? ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='saha_musteri' ORDER BY ordinal_position;"

echo
echo "############ 2) ZIYARET FORMU — hangi alanlari TOPLUYOR? (880-975) ############"
awk 'NR>=880 && NR<=975 { printf "%5d| %s\n", NR, $0 }' shells/saha.js

echo
echo "############ 3) FORM ACILIRKEN — musteri verisi OKUNUYOR mu? (925-945) ############"
awk 'NR>=920 && NR<=950 { printf "%5d| %s\n", NR, $0 }' shells/saha.js
echo "  ⚠ Yukarida sadece sektorler ve tedarikci_markalar okunuyor gorunuyor."
echo "     vkn/tc/yetkili/telefon/arac_parki/yillik_potansiyel OKUNUYOR MU?"

echo
echo "############ 4) ⚠ VERI GERCEKTEN VAR MI? — musterilerde ne dolu? ############"
$PSQL -c "
SELECT count(*)                                          AS musteri,
       count(vergi_no)                                   AS vkn_dolu,
       count(tc_no)                                      AS tc_dolu,
       count(yetkili)                                    AS yetkili_dolu,
       count(telefon)                                    AS telefon_dolu,
       count(*) FILTER (WHERE sektorler IS NOT NULL AND array_length(sektorler,1) > 0)          AS sektor_dolu,
       count(*) FILTER (WHERE tedarikci_markalar IS NOT NULL AND array_length(tedarikci_markalar,1) > 0) AS marka_dolu
  FROM saha_musteri WHERE aktif;"
echo "  ⚠ 'sektor_dolu' ve 'marka_dolu' DUSUKSE: 403 kapisi yuzunden hic yazilamamis."
echo "     Bugun kapi kalkti — bundan sonraki ziyaretlerde dolacak."

echo
echo "############ 5) EKSIK ALANLAR — form topluyor ama musteride YOK olanlar ############"
grep -n "arac_parki\|yillik_potansiyel\|kullanilan_marka\|mevcut_tedarikci" shells/saha.js | head -8
$PSQL -c "SELECT column_name FROM information_schema.columns
          WHERE table_name='saha_musteri'
            AND column_name IN ('arac_parki','yillik_potansiyel','kullanilan_markalar','mevcut_tedarikci','sektorler','tedarikci_markalar');"
echo "  ⚠ Formun topladigi ama tabloda KARSILIGI OLMAYAN alan varsa,"
echo "     o veri ziyaret detayina (detay jsonb) gomuluyordur — musteriye YAZILMIYOR."

echo
echo "############ 6) ZIYARET.detay — icinde ne var? (ornek) ############"
$PSQL -x -c "
SELECT detay FROM saha_ziyaret
 WHERE detay IS NOT NULL AND detay::text <> '{}'
 ORDER BY created_at DESC LIMIT 2;"
