#!/usr/bin/env bash
# GORUNUM_DAYANIKLI_MI — Fatih dogru soruyu sordu: yeni ERP verisi bunu KIRAR MI?
#
# ⚠ IKI GERCEK RISK. IKISI DE YUKLEMEYLE ILGILI. TAHMIN ETMIYORUM, OLCUYORUM.
#
#   RISK 1 — MOTOR TABLOYU DROP EDERSE GORUNUM OLUR.
#     erp_ingest.py anlik tablolar icin "tam_degistir" modu kullaniyor.
#     DELETE / TRUNCATE ise -> gorunum HAYATTA KALIR.
#     DROP TABLE ... CASCADE ise -> GORUNUMU DE SESSIZCE SILER.
#     Sonraki yukleme calisir, hicbir hata gorunmez, ve 62 sorgu ertesi gun
#     "relation does not exist" der. Tam olarak bugun kovaladigimiz sessiz kirilma.
#
#   RISK 2 — PERFORMANS.
#     bi_stok_durumu gorunumu her cagrildiginda tedarikci faturalarinin TAMAMI
#     uzerinde DISTINCT ON calistiriyor. 37 sorgu bunu okuyor.
#
# ⚠ VE DURUSTLUK: gorunum bir KOPRU, varis noktasi degil.
#   Dogrusu 62 sorguyu yeniden yazmak. Gorunum bugunu kurtariyor ve yanlis sayiyi
#   HEMEN durduruyor; kalici cozum sorgularin kendisi.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ RISK 1) ⚠ MOTOR NE YAPIYOR? — tam_degistir'in KODU ############"
grep -n "tam_degistir\|DROP TABLE\|TRUNCATE\|DELETE FROM" erp_ingest.py | head -20
echo
echo "  --- yukleme fonksiyonunun silme kismi (tam kod) ---"
awk '/yukleme_modu.*tam_degistir/,0' erp_ingest.py | head -5
L=$(grep -n "def yukle" erp_ingest.py | head -1 | cut -d: -f1)
awk -v s="$L" 'NR>=s && NR<=s+90 { if ($0 ~ /DELETE|TRUNCATE|DROP|tam_degistir|tarih_araligi|execute/) printf "%5d| %s\n", NR, $0 }' erp_ingest.py

echo
echo "############ ⚠ HUKUM ############"
if grep -q "DROP TABLE.*bi_stok_anlik\|DROP TABLE.*bi_musteri_risk\|DROP TABLE.*bi_tedarikci" erp_ingest.py; then
  echo "  ❌ MOTOR TABLO DUSURUYOR -> gorunum KIRILIR. Yamamam lazim."
else
  echo "  ✅ Motor DROP TABLE kullanmiyor gorunuyor — ama asagida CANLI TEST var."
fi

echo
echo "############ 2) ⚠⚠ CANLI TEST — gorunum bagimliligi DROP'u ENGELLER mi? ############"
echo "  (Postgres, gorunum bagli bir tabloyu DROP etmeyi REDDEDER — bu bizim LEHIMIZE.)"
$PSQL -c "BEGIN; DROP TABLE bi_stok_anlik; ROLLBACK;" 2>&1 | head -3
echo "  ⚠ 'cannot drop ... because other objects depend on it' -> ✅ GORUNUM KORUYOR."
echo "     Yani motor DROP denerse HATA ALIR ve DURUR. Sessizce kirilmaz."
echo "  ⚠ Ama CASCADE ile DROP ederse gorunum de gider. Onu da test ediyorum:"
$PSQL -c "BEGIN; DROP TABLE bi_stok_anlik CASCADE; SELECT count(*) FROM pg_views WHERE viewname='bi_stok_durumu'; ROLLBACK;" 2>&1 | head -5
echo "     ⚠ Yukarida 0 cikarsa: CASCADE gorunumu SILER. Motor CASCADE kullaniyorsa TEHLIKE."

echo
echo "############ 3) ⚠ PERFORMANS — gorunum ne kadar yavas? ############"
echo "  --- bi_stok_durumu (GORUNUM) ---"
$PSQL -c "\timing on" -c "
SELECT count(*), round(sum(toplam_deger)/1e6,1) FROM bi_stok_durumu
 WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id='$T'::uuid);"
echo "  --- ayni sorgu, YEDEK TABLODAN (eski hiz referansi) ---"
$PSQL -c "\timing on" -c "
SELECT count(*), round(sum(toplam_deger)/1e6,1) FROM bi_stok_durumu_olu_yedek
 WHERE tenant_id='$T'::uuid;"
echo "  --- bi_stok_hareketleri (GORUNUM) ---"
$PSQL -c "\timing on" -c "SELECT count(*) FROM bi_stok_hareketleri WHERE tenant_id='$T'::uuid;"

echo
echo "############ 4) ⚠ ANA SAYFA — gercek kullanici deneyimi ############"
for i in 1 2 3; do
  T0=$(date +%s%3N)
  curl -s -o /dev/null http://localhost:8080/api/bi/ana
  T1=$(date +%s%3N)
  echo "  /api/bi/ana  deneme $i : $((T1-T0)) ms"
done
echo "  ⚠ 2000 ms ustu ise kullanici FARK EDER. Gorunumu MATERIALIZED yapmak gerekir."
