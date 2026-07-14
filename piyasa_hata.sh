#!/usr/bin/env bash
# PIYASA_HATA — "Piyasa bilgisi ekranina veri girilemiyor" (Eftal, bugun 08:30)
#
# ⚠ Bu bir oneri degil, bir ARIZA. Bir ekran calismiyor ve kimse bakmamis.
#
# ⚠ VE MUKERRER ZIYARETIN SEBEBINI de ariyorum:
#   Eftal: "Harun Bozbag'da 2 kayit olusmus."
#   Bugun konum verisinde gormustum: HARUN BOZBAG, 15:07, IKI KEZ, AYNI KOORDINAT.
#   Eftal dogru soyluyor. "Silme ozelligi ekle" SEBEBI DURDURMAZ — once NEDEN olustugunu bul.
#
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ BUGUNKU HATALAR — Piyasa ekrani ne diyor? ############"
$PSQL -c "
SELECT to_char(ts,'DD HH24:MI') AS saat, u.full_name AS kim,
       h.tip, h.view_adi, h.http_status AS kod, h.endpoint,
       left(h.hata_mesaji, 60) AS hata
  FROM saha_hata_log h LEFT JOIN users u ON u.id=h.user_id
 WHERE h.ts >= current_date - 1
 ORDER BY h.ts DESC LIMIT 25;"

echo
echo "############ 2) PIYASA EKRANI — arayuz hangi uc noktayi cagiriyor? ############"
grep -n "piyasa" shells/saha.js | head -20

echo
echo "############ 3) SUNUCU — piyasa uc noktalari ############"
grep -n "piyasa\|rakip-teklif\|market-intel" server_container.mjs | grep -i "method ===\|path ===" | head -10

echo
echo "############ 4) PIYASA TABLOSU — veri geliyor mu? ############"
$PSQL -c "
SELECT relname, n_live_tup FROM pg_stat_user_tables
 WHERE relname ~ 'piyasa|rakip_teklif|market' ORDER BY n_live_tup DESC;"
$PSQL -c "SELECT column_name, data_type, is_nullable FROM information_schema.columns
          WHERE table_name='saha_rakip_teklif' ORDER BY ordinal_position;" 2>/dev/null
$PSQL -c "SELECT count(*), max(created_at) FROM saha_rakip_teklif;" 2>/dev/null

echo
echo "############ 5) ⚠⚠ MUKERRER ZIYARET — Harun Bozbag ############"
$PSQL -x -c "
SELECT z.id, z.created_at, z.ziyaret_tarihi, z.durum,
       z.checkin_at, z.checkin_lat, z.checkin_lng,
       left(z.notlar, 60) AS not
  FROM saha_ziyaret z
  JOIN saha_musteri m ON m.id = z.musteri_id
 WHERE m.firma ILIKE '%HARUN BOZBA%'
 ORDER BY z.created_at;"

echo
echo "  --- ⚠ SISTEMDE KAC MUKERRER ZIYARET VAR? (ayni rep + musteri + gun) ---"
$PSQL -c "
SELECT count(*) AS mukerrer_grup, sum(adet - 1) AS fazladan_kayit
  FROM (
    SELECT rep_id, musteri_id, ziyaret_tarihi, count(*) AS adet
      FROM saha_ziyaret
     GROUP BY 1,2,3 HAVING count(*) > 1
  ) x;"
$PSQL -c "
SELECT m.firma, u.full_name AS rep, z.ziyaret_tarihi, count(*) AS adet,
       min(z.created_at) AS ilk, max(z.created_at) AS son,
       max(z.created_at) - min(z.created_at) AS aradaki_sure
  FROM saha_ziyaret z
  JOIN saha_musteri m ON m.id=z.musteri_id
  LEFT JOIN users u ON u.id=z.rep_id
 GROUP BY 1,2,3 HAVING count(*) > 1
 ORDER BY max(z.created_at) DESC LIMIT 10;"
echo "  ⚠ 'aradaki_sure' saniyeler ise: CIFT TIKLAMA / yeniden gonderim."
echo "     Dakikalar/saatler ise: kullanici bilerek ikinci kez girmis (baska sorun)."

echo
echo "############ 6) ZIYARET KAYDETME — cift gonderime karsi koruma VAR MI? ############"
grep -n "POST.*api/saha/ziyaretler\"" server_container.mjs
L=$(grep -n 'method === "POST" && path === "/api/saha/ziyaretler"' server_container.mjs | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+30 { printf "%5d| %s\n", NR, $0 }' server_container.mjs
echo "  ⚠ UNIQUE kisit ya da 'zaten var mi' kontrolu yoksa: her tiklama YENI KAYIT."
