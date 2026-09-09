echo "############ KRB PROMPT BANDI — bilinen sabitler duruyor mu ############"
echo "### Bant 1: on-siparis / erken-al zinciri (24600-24700)"
grep -nE "adet: *[0-9]{4}|%7,1|7\.1|iki ayl|erken al|sermaye.*%[0-9]" server_container.mjs | grep -vE "^\s*[0-9]+:\s*//" 

echo
echo "### Bant 2: DB_SCHEMA satir sayilari (25600-25700)"
sed -n '25608,25700p' server_container.mjs | grep -nE "[0-9]{2}\.[0-9]{3}|[0-9]+ satir|CANLI —" 

echo
echo "### Bant 3: rakip tarama iddialari (26400 + 31700)"
grep -nE "68\.000|68\.729|292|%36|~90 KAT|eslesme orani %" server_container.mjs | grep -vE "^\s*[0-9]+:\s*//"

echo
echo "### Bant 4: %100 dogrulama iddiasi + %74/%0"
grep -nE "%100 dogrulan|%100 do|TABAN TABANA|%74|bazıları %0" server_container.mjs | grep -vE "^\s*[0-9]+:\s*//"
