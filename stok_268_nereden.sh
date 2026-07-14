#!/usr/bin/env bash
# STOK_268_NEREDEN — 268,5M'yi ben soyledim. NEREDEN geldigini kanitlamaliyim.
#
# ⚠ CELISKI:
#   Canli stok × son hareket maliyeti = 348,1M
#   Benim Fatih'e soyledigim              = 268,5M  (SAP'in kendi degeri 282,4M ile dogrulamistim)
#   %30 FARK. Ikisinden biri yanlis — ya da ikisi FARKLI SEY olcuyor.
#
# ⚠ Yanlis maliyet kaynagini secersem MARJI, STOK DEVRINI ve SERMAYE YUKUNU
#   ayni anda bozarim. Uc rakam da yonetim kararlarina giriyor.
#
# ⚠ Ayrica bi_maliyet_sku sorgusu PATLADI ama tablo VAR. Neden?
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) bi_maliyet_sku — neden patladi? ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_maliyet_sku' ORDER BY ordinal_position;"
$PSQL -c "SELECT count(*) FROM bi_maliyet_sku;"
$PSQL -x -c "SELECT * FROM bi_maliyet_sku LIMIT 2;"

echo
echo "############ 2) ⚠ 268,5M — ekranda hangi sorgu uretiyor? ############"
grep -n "268\|stok_deger\|stokDeger\|sermaye" server_container.mjs | grep -iv "^.*//" | head -10
echo "  --- /api/bi/ana icindeki stok hesabi ---"
L=$(grep -n "'/api/bi/ana'\|\"/api/bi/ana\"" server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+80 { if ($0 ~ /stok|sermaye|deger/) printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 3) ⚠⚠ STOK DEGERI — TUM yollar yan yana ############"
echo "  --- YOL B: bi_maliyet_sku (dogru kolon adlariyla) ---"
$PSQL -c "
SELECT round(sum(a.adet * m.birim_maliyet)/1e6, 1) AS deger_M,
       count(*) FILTER (WHERE m.birim_maliyet IS NULL) AS maliyetsiz_sku
  FROM bi_stok_anlik a
  LEFT JOIN bi_maliyet_sku m ON m.kalem_kodu = a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);" 2>&1 | head -6

echo "  --- YOL E: SAP'in KENDI stok bakiyesi (stok_bakiye_tutari, depo bazli) ---"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (depo, kalem_kodu) depo, kalem_kodu, stok_bakiye_tutari
    FROM bi_stok_hareket
   WHERE tenant_id='$T'::uuid
   ORDER BY depo, kalem_kodu, belge_tarihi DESC, ingested_at DESC
)
SELECT round(sum(stok_bakiye_tutari)/1e6, 1) AS deger_M, count(*) AS satir
  FROM son;"
echo "    ⚠ Bunu daha once 282,4M olarak olcup 268,5M ile %5,1 uyumlu bulmustum."

echo "  --- YOL F: bi_marj_fact'in kullandigi maliyet (marj hesabinin kaynagi) ---"
$PSQL -c "
SELECT round(sum(a.adet * mf.birim_maliyet)/1e6, 1) AS deger_M,
       count(*) FILTER (WHERE mf.birim_maliyet IS NULL) AS maliyetsiz_sku
  FROM bi_stok_anlik a
  LEFT JOIN LATERAL (
    SELECT birim_maliyet FROM bi_marj_fact f
     WHERE f.tenant_id=a.tenant_id AND f.kalem_kodu=a.kalem_kodu
     ORDER BY ay DESC LIMIT 1
  ) mf ON true
 WHERE a.tenant_id='$T'::uuid
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);" 2>&1 | head -6

echo
echo "############ 4) ⚠ EN PAHALI SKU'LAR — hangi maliyet MANTIKLI? ############"
$PSQL -c "
WITH son_hareket AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND birim_maliyet > 0
   ORDER BY kalem_kodu, belge_tarihi DESC
)
SELECT left(a.kalem_tanimi, 38) AS urun, a.marka, a.adet,
       round(s.birim_maliyet)   AS hareket_maliyeti,
       round(a.liste_fiyati)    AS liste_fiyati,
       round(a.adet * s.birim_maliyet / 1e6, 1) AS deger_M
  FROM bi_stok_anlik a
  LEFT JOIN son_hareket s ON s.kalem_kodu = a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid)
 ORDER BY a.adet * s.birim_maliyet DESC NULLS LAST LIMIT 8;"
echo "  ⚠ 'hareket_maliyeti' liste fiyatindan BUYUKSE, o maliyet BOZUK demektir."
echo "     (maliyet > satis fiyati -> her satista zarar ediyor gorunurdu)"
