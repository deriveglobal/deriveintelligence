#!/usr/bin/env bash
# ALACAK_MUTABAKAT — degistirmeden ONCE olc. Sadece OKUR.
#
# ⚠ KANITLANDI:
#   bi_musteri_bakiye :    399 musteri · 12 Haziran · 145,4M   -> OLU ve EKSIK
#   bi_musteri_risk   : 38.604 musteri · 12 Temmuz             -> CANLI ve TAM
#   bi_cari_bakiye    :    403 tedarikci · 14 Temmuz           -> TEDARIKCI tarafi (ayri sey)
#
# ⚠ VE master_musteri.son_bakiye / vadesi_gecmis, OLU tablodan doluyor (27637-27645).
#   38.628 musterinin sadece 399'u icin. Bugun musteri kartina "kanit" diye
#   o iki alani BEN ekledim. Kaynagina bakmadan. Tam da elestirdigim seyi yaptim.
#
# ⚠ VE SIMDI EMIN OLMADIGIM BIR SEY DAHA VAR:
#   Ana sayfadaki "alacak 238,8M" nereden geliyor? Olu tablo 145,4M diyor.
#   Ucuncu bir sayi varsa, deger agacinin tamami sorgulanmali.
#   IDDIA ETMIYORUM — OLCUYORUM.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ ALACAK — uc kaynak, uc sayi? ############"
$PSQL -c "
SELECT 'bi_musteri_bakiye (OLU)' AS kaynak,
       count(*)                             AS musteri,
       round(sum(bakiye)/1e6, 1)            AS bakiye_M,
       round(sum(vadesi_gecmis_tutar)/1e6,1) AS vadesi_gecmis_M,
       max(export_date)::text                AS tarih
  FROM bi_musteri_bakiye
UNION ALL
SELECT 'bi_musteri_risk (CANLI, musteri_mi)',
       count(*),
       round(sum(hesap_bakiyesi)/1e6, 1),
       round(sum(vadesi_gecmis)/1e6, 1),
       max(export_date)::text
  FROM bi_musteri_risk WHERE musteri_mi
UNION ALL
SELECT 'bi_musteri_risk — bakiyesi SIFIR OLMAYAN',
       count(*) FILTER (WHERE hesap_bakiyesi <> 0),
       round(sum(hesap_bakiyesi) FILTER (WHERE hesap_bakiyesi <> 0)/1e6, 1),
       round(sum(vadesi_gecmis)  FILTER (WHERE vadesi_gecmis  <> 0)/1e6, 1),
       max(export_date)::text
  FROM bi_musteri_risk WHERE musteri_mi;"

echo
echo "############ 2) ⚠ ANA SAYFADAKI 238,8M NEREDEN GELIYOR? ############"
grep -n "alacak\|238\|net_isletme\|nis_alacak" server_container.mjs | grep -i "select\|sum\|from bi_" | head -10
echo "  --- /api/bi/ana icindeki alacak hesabi ---"
L=$(grep -n '"/api/bi/ana"' server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+60 { if ($0 ~ /alacak|bakiye|risk/) printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 3) master_musteri — kac musterinin bakiyesi DOLU? ############"
$PSQL -c "
SELECT count(*)                                    AS master_musteri,
       count(son_bakiye)                           AS bakiyesi_dolu,
       count(*) - count(son_bakiye)                AS bakiyesi_BOS,
       round(sum(son_bakiye)/1e6, 1)               AS toplam_M
  FROM master_musteri;"
echo "  ⚠ 'bakiyesi_BOS' buyukse: musteri kartlarinin cogunda bakiye HIC YOK."

echo
echo "############ 4) ⚠ AYNI MUSTERI, IKI KAYNAK — ne kadar sapiyor? ############"
$PSQL -c "
SELECT count(*)                                              AS ortak,
       count(*) FILTER (WHERE abs(b.bakiye - r.hesap_bakiyesi) < 1)   AS ayni,
       count(*) FILTER (WHERE abs(b.bakiye - r.hesap_bakiyesi) >= 1)  AS sapan,
       round(max(abs(b.bakiye - r.hesap_bakiyesi))/1e3, 1)   AS en_buyuk_sapma_bin_TL
  FROM bi_musteri_bakiye b
  JOIN bi_musteri_risk  r ON r.muhatap_kodu = b.musteri_kodu AND r.musteri_mi;"
echo "  ⚠ Bir ay arayla cekilmis iki tablo — sapma NORMAL. Ama BUYUKLUGU onemli."

echo
echo "############ 5) EN BUYUK ALACAKLAR — canli kaynaktan (gercek tablo) ############"
$PSQL -c "
SELECT left(muhatap_adi, 32) AS musteri,
       round(hesap_bakiyesi/1e3, 0) AS bakiye_bin,
       round(vadesi_gecmis/1e3, 0)  AS vadesi_gecmis_bin,
       round(kredi_limiti/1e3, 0)   AS limit_bin,
       round(toplam_risk/1e3, 0)    AS risk_bin
  FROM bi_musteri_risk
 WHERE musteri_mi AND hesap_bakiyesi > 0
 ORDER BY hesap_bakiyesi DESC LIMIT 10;"

echo
echo "############ 6) CEO ASISTANI — hangi tablolari 'biliyor'? ############"
awk 'NR>=25525 && NR<=25545 { printf "%5d| %s\n", NR, $0 }' server_container.mjs
