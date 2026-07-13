#!/usr/bin/env bash
# ANA_UI_V1 dagitimi — yeni 'Bugün' ana sayfasi.
# ⚠ Eski 'home' odasi DOKUNULMUYOR. Yeni oda ekleniyor, varsayilan o oluyor.
#   Geri alma = tek dosya kopyala.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 0) ANCHOR — taze grep ############"
grep -n "let activeDept = 'home'" shells/bi.js | head -1
grep -n 'data-dept="home"' shells/bi.js | head -1
grep -n "Brain Room (created outside" shells/bi.js | head -1

echo
echo "############ 1) YEDEK ############"
cp shells/bi.js shells/bi.js.bak_anaui
ONCE=$(wc -c < shells/bi.js)

echo
echo "############ 2) YAMA ############"
python3 patch_ana_ui.py || { echo "❌ geri aliniyor"; cp shells/bi.js.bak_anaui shells/bi.js; exit 1; }
SONRA=$(wc -c < shells/bi.js)
echo "  boyut: $ONCE -> $SONRA"
[ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/bi.js.bak_anaui shells/bi.js; exit 1; }

echo
echo "############ 3) ⚠ KAPI: SOZDIZIMI ############"
node --check shells/bi.js || { echo "❌ NODE FAIL — GERI ALINIYOR"
  cp shells/bi.js.bak_anaui shells/bi.js; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) ⚠ KAPI: eski 'home' odasi HALA DURUYOR MU? ############"
grep -q "vmo-room-home" shells/bi.js && echo "  ✅ eski home korundu (ulasilmaz ama saglam)" || {
  echo "  ❌ eski home SILINMIS — bu olmamaliydi"; cp shells/bi.js.bak_anaui shells/bi.js; exit 1; }

echo
echo "############ 5) ⚠ KAPI: yeni oda + fonksiyon var mi? ############"
for T in "vmo-room-bugun" "ciz_bugun" "ANA_UI_V1" "activeDept = 'bugun'"; do
  grep -q -- "$T" shells/bi.js || { echo "  ❌ YOK: $T"; cp shells/bi.js.bak_anaui shells/bi.js; exit 1; }
done
echo "  ✅ hepsi yerinde"

echo
echo "############ 6) DAGIT ############"
docker cp shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
curl -s -o /dev/null -w "  GET /shells/bi.js -> HTTP %{http_code}\n" http://localhost:8080/shells/bi.js

echo
echo "############ 7) CANLI: yeni kod servis ediliyor mu? ############"
curl -s http://localhost:8080/shells/bi.js | grep -c "ANA_UI_V1" | xargs -I{} echo "  ANA_UI_V1 canlida: {} kez"

echo
echo "############ 8) SUNUCU LOGU ############"
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -5 || echo "  temiz"

git add -A && git commit -q -m "feat(ana): ANA_UI_V1 — yeni 'Bugün' ana sayfasi. ⚠ Eski 'home' odasi (beyin/hub canvas) DOKUNULMADI: canvas+glow+animasyon kodu tasiyor, Pazartesi 8 temsilci canli, calisan blogu sokup yenisini koymak JS hatasi riski = giris ekrani BOS. Yeni oda eklendi, varsayilan acilis o; eski home kodda kaldi, sekmesi yok, ulasilmaz. Ekran: bagli sermaye omurgasi (507M · 203M yillik yuk · 131 gun stok · 116 gun GERCEK DSO) · KARLILIK KUTUSU 'hesaplanamiyor' + eksik dosya listesi + yukleme butonu (sistemin ilk soyledigi sey KENDI KORLUGU) · karar kuyrugu (puan + BILESENLERI gorunur, itiraz edilebilir) · planli odemeler AYRI ve sessiz · vardiya defteri · asistan seridi. Her sayi dokunma noktasi: tiklaninca asistana baglamsal soru gidiyor. Hicbir rakam kodda gomulu degil — hepsi /api/bi/ana'dan, o da Postgres'te dogrulandi." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp shells/bi.js.bak_anaui shells/bi.js && docker cp shells/bi.js krb-assessment:/app/shells/bi.js && docker restart krb-assessment"
