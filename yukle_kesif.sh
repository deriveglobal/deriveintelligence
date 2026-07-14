#!/usr/bin/env bash
# YUKLE_KESIF — yukleme uc noktasinin YUKLEME SONRASI kodu. Sadece OKUR.
#
# ⚠ KANITLANDI: master_musteri SUNUCU ACILISINDA kuruluyor.
#   refreshed_at 04:58:14.237 · konteyner basladi 04:58:13.319 — bir saniye bile yok.
#
# ⚠ VE BU, durum'dan COK DAHA BUYUK:
#   refreshSahaMasters() sadece master_musteri'yi degil; marka_kirilimi,
#   kategori_kirilimi, fiyat listesi eslesmesi ve saha_cari_cache'i de kuruyor.
#   Yarin yeni satis faturasi yuklenir, konteyner yeniden BASLAMAZ:
#     - master_musteri dunku halinde kalir
#     - yeni musteriler typeahead'de CIKMAZ
#     - ciro kirilimlari ESKIR
#     - durum ESKI master'dan hesaplanir
#   ve HICBIR YERDE HATA GORUNMEZ.
#   Bugune kadar fark edilmedi cunku her dagitimda konteyner yeniden basliyordu;
#   master da TESADUFEN tazeleniyordu. Dagitimi biraktigimiz gun sessizce eskir.
#
# ⚠ COZUM: yukleme bitince sunucu KENDI refreshSahaMasters()'ini cagirsin.
#   Kendi SQL'imi YAZMIYORUM — ayni tabloyu iki yerde kuran iki SQL,
#   er ya da gec IKI GERCEK uretir. Once cagirma noktasini gorecegim.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) /api/bi/yukle — uc noktanin tamami ############"
L=$(grep -n '"/api/bi/yukle"' server_container.mjs | head -1 | cut -d: -f1)
echo "  baslangic: $L"
awk -v s="$L" 'NR>=s && NR<=s+75 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 2) erp_ingest.py'yi calistiran yer (spawn/exec) ############"
grep -n "erp_ingest\|spawn\|execFile\|child_process" server_container.mjs | head -10

echo
echo "############ 3) refreshSahaMasters — tanim ve TUM cagrilari ############"
grep -n "refreshSahaMasters\|refreshSahaCariCache" server_container.mjs

echo
echo "############ 4) Acilista kim cagiriyor? (baglami gor) ############"
for F in refreshSahaMasters refreshSahaCariCache; do
  for LN in $(grep -n "await $F(" server_container.mjs | cut -d: -f1); do
    echo "  --- $F cagrisi @ $LN ---"
    awk -v s="$((LN-8))" -v e="$((LN+3))" 'NR>=s && NR<=e { printf "%5d| %s\n", NR, $0 }' server_container.mjs
  done
done

echo
echo "############ 5) erp_ingest.py — yukleme sonrasi ne donduruyor? ############"
grep -n "def yukle\|def ana\|turet(\|return {" erp_ingest.py | head -12
