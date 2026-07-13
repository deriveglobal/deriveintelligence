#!/usr/bin/env bash
# Salt okuma. 'ciro' kelimesinin ve beyin promptunun TAM yerini bul.
# Hafizadan anchor UYDURMAYACAGIM -- taze grep.
S=/opt/krb-assessment/server_container.mjs

echo "############ 1) BEYIN PROMPTU (_buildBrainPrompt) ############"
grep -n "_buildBrainPrompt\|function _buildBrainPrompt" $S | head
L=$(grep -n "^async function _buildBrainPrompt\|^function _buildBrainPrompt" $S | head -1 | cut -d: -f1)
echo "  -- fonksiyonun ilk 30 satiri (anchor secmek icin) --"
[ -n "$L" ] && sed -n "$L,$((L+30))p" $S

echo
echo "############ 2) 'VERI DURUSTLUGU' / guardrail bolumu var mi? ############"
grep -n "DURUSTL\|DÜRÜST\|GUARDRAIL\|HONESTY\|bilmiyorsan\|uydurma\|BILMEDIGIN" $S | head -12

echo
echo "############ 3) 'ciro' gecen TUM yerler (etiketlenecek) ############"
grep -n "ciro\|Ciro\|CIRO" $S | grep -v "^.*//" | head -30

echo
echo "############ 4) satir_tutar toplayan sorgular (ciro hesabi) ############"
grep -n "sum(satir_tutar)\|SUM(satir_tutar)" $S | head -20

echo
echo "############ 5) BI kabugunda 'Ciro' etiketi ############"
grep -n "Ciro\|ciro" /opt/krb-assessment/shells/bi.js | head -20

echo
echo "############ 6) grup_adi filtresi kullanan var mi? ############"
grep -n "grup_adi" $S | head -10
echo "  ^ Hicbiri LASTIK ile sinirlamiyorsa: sorgular zaten TUM veriyi topluyor,"
echo "    ama veri ZATEN sadece lastik. Yani sorun SQL'de degil, ETIKETTE."
