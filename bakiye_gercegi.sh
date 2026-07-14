#!/usr/bin/env bash
# BAKIYE_GERCEGI — kesmeden once TEK SORU: musteri ALACAK bakiyesinin CANLI kaynagi ne?
#
# ⚠ BUGUN YAPTIGIM HATA:
#   Musteri kartina "kanit" diye bakiye + vadesi_gecmis ekledim (master_musteri'den).
#   Ama master_musteri.son_bakiye'yi refreshSahaMasters, bi_musteri_bakiye'den doldurluyor
#   (satir 27642) — ve o tablo 12 HAZIRAN'dan beri OLU. 32 gun.
#   Yani etiketi duzelttim, YANINA YALAN BIR SAYI KOYDUM. Kaynaga bakmadan "kanit" dedim.
#
# ⚠ VE DIKKAT: bi_cari_bakiye (403 satir) BUNUN YERINE GECMEZ.
#   O TEDARIKCI bakiyesi (KRB'nin BORCU). bi_musteri_bakiye ise MUSTERI ALACAGI.
#   Ikisini karistirirsam alacaklari borc sanarim. Aday: bi_musteri_risk (accountriskreport).
#
# Sadece OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ADAYLAR — hangisi MUSTERI, hangisi TEDARIKCI? ############"
for T in bi_musteri_bakiye bi_cari_bakiye bi_musteri_risk; do
  echo "  ══════ $T ══════"
  $PSQL -c "SELECT column_name, data_type FROM information_schema.columns
            WHERE table_name='$T' ORDER BY ordinal_position;" 2>/dev/null || echo "  (tablo yok)"
done

echo
echo "############ 2) TAZELIK — hangisi yasiyor? ############"
$PSQL -c "SELECT 'bi_musteri_bakiye' t, count(*) satir, max(export_date)::text son FROM bi_musteri_bakiye
UNION ALL SELECT 'bi_cari_bakiye',    count(*), max(export_date)::text FROM bi_cari_bakiye
UNION ALL SELECT 'bi_musteri_risk',   count(*), max(export_date)::text FROM bi_musteri_risk;"
echo "  ⚠ Bugun 14 Temmuz. 30+ gun geride olan OLU demektir."

echo
echo "############ 3) ⚠ ORNEK SATIRLAR — kim kime borclu? ############"
echo "  --- bi_musteri_risk (accountriskreport) ---"
$PSQL -x -c "SELECT * FROM bi_musteri_risk ORDER BY export_date DESC LIMIT 2;" 2>/dev/null

echo "  --- bi_cari_bakiye ---"
$PSQL -x -c "SELECT * FROM bi_cari_bakiye LIMIT 2;" 2>/dev/null

echo
echo "############ 4) ⚠⚠ MUTABAKAT — ayni musteri, uc kaynak, ayni sayi mi? ############"
$PSQL -c "
SELECT r.musteri_kodu,
       left(r.musteri_adi, 26) AS musteri,
       b.bakiye        AS olu_tablo_bakiye,
       mm.son_bakiye   AS master_bakiye,
       r.*
  FROM bi_musteri_risk r
  LEFT JOIN bi_musteri_bakiye b ON b.musteri_kodu = r.musteri_kodu
  LEFT JOIN master_musteri mm   ON mm.musteri_kodu = r.musteri_kodu
 LIMIT 3;" 2>/dev/null | head -30

echo
echo "############ 5) master_musteri.son_bakiye — GERCEKTEN olu tablodan mi geliyor? ############"
cd /opt/krb-assessment
awk 'NR>=27636 && NR<=27660 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 6) ⚠ NE KADAR SAPIYOR? (olu bakiye vs risk raporu) ############"
$PSQL -c "
SELECT count(*) AS ortak_musteri,
       round(sum(b.bakiye)/1e6, 1)  AS olu_tablo_toplam_M,
       max(b.export_date)           AS olu_tablo_tarih
  FROM bi_musteri_bakiye b;"
$PSQL -c "SELECT count(*) AS risk_musteri, max(export_date) AS risk_tarih FROM bi_musteri_risk;"
echo "  ⚠ Musteri sayilari cok farkliysa (399 vs 38.604), olu tablo zaten EKSIKTI."
