#!/usr/bin/env bash
# UC_ARIZA_KESIF — uc gercek ariza, ucu de bugun. Sadece OKUR.
#
# ⚠ 1) PIYASA: "Can't find variable: g" ×16 (Eftal, 10:17 ve 10:23)
#      saha.js:5415'te g("dy-baslik") cagriliyor ama g O KAPSAMDA TANIMLI DEGIL.
#
# ⚠ 2) MUKERRER ZIYARET: 35 grup, 37 fazladan kayit. SEBEP NET:
#      HARUN BOZBAG (Eftal) : iki kayit arasi 1,16 SANIYE  -> CIFT TIKLAMA
#      UZUNLAR (Huseyin)    : 33 SANIYE — ve tam o saatlerde YAVAS_API uyarilari var
#                             (14:02, 14:10, 14:14, 14:18, 14:22, 14:30)
#      Yani: kaydet -> ekran donuyor -> adam "olmadi" saniyor -> tekrar basiyor -> IKI KAYIT.
#      ⚠ YAVAS API MUKERRER KAYIT URETIYOR. "Silme butonu" SEBEBI DURDURMAZ.
#
# ⚠ 3) VE BENIM YAMAM YENI BIR HATA DOGURDU:
#      Eftal bugun 11:28 ve 11:54'te 400 — "Guncellenecek alan yok" aldi.
#      403'u kaldirdim, istek artik sunucuya ULASIYOR — ama arayuz BOS PUT atiyor.
#      Once sessizce 403 yiyordu, simdi gorunur 400 veriyor.
#      Ilerleme (sessiz -> gorunur) ama HALA HATA. Kaynak: arayuz bos istek atmamali.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) 'g' NEREDE TANIMLI? ############"
grep -n "function g(\|const g =\|let g =\|var g =\|  g = \|g = (" shells/saha.js | head -10

echo
echo "  --- 'g(' KULLANIMLARI (hangi fonksiyonlarin icinde?) ---"
grep -n "\bg(\"" shells/saha.js | head -15

echo
echo "############ 2) PIYASA GORUNUMU — vPiyasa + dosyaYukleModal (5320-5430) ############"
awk 'NR>=5320 && NR<=5430 { printf "%5d| %s\n", NR, $0 }' shells/saha.js

echo
echo "############ 3) ⚠ BOS PUT — ziyaret formu ne gonderiyor? (990-1010 + 1250-1265) ############"
awk 'NR>=988 && NR<=1010 { printf "%5d| %s\n", NR, $0 }' shells/saha.js
echo "  ---"
awk 'NR>=1248 && NR<=1266 { printf "%5d| %s\n", NR, $0 }' shells/saha.js

echo
echo "############ 4) ZIYARET KAYDET BUTONU — cift tiklama korumasi var mi? ############"
grep -n "ziyaretler\", { method: \"POST\"\|api(\"/api/saha/ziyaretler\", { method" shells/saha.js
grep -n "disabled = true\|disabled=true\|btn.disabled" shells/saha.js | head -8
echo "  ⚠ Kaydet butonunda 'disabled = true' YOKSA: her tiklama yeni istek."

echo
echo "############ 5) ⚠ YAVAS API — /api/saha/ziyaretler NEDEN yavas? ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT count(*) AS ziyaret_satiri FROM saha_ziyaret;"
L=$(grep -n 'method === "GET" && path === "/api/saha/ziyaretler"' server_container.mjs | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+38 { printf "%5d| %s\n", NR, $0 }' server_container.mjs
echo "  ⚠ LIMIT yoksa ya da her ziyarette alt sorgu varsa: liste buyudukce YAVASLAR."
echo "     Ve yavaslik MUKERRER KAYIT uretiyor. Kok sebep BURADA."
