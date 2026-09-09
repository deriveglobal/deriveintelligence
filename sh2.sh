PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. handleSahaApi YONLENDIRME KALIBI ############"
sed -n '28001,28060p' server_container.mjs

echo
echo "############ 2. SAHA UC SAYIMI (dogru kalip) ############"
sed -n '28001,32356p' server_container.mjs | grep -oE '(seg|path|route|===)[^;]{0,40}saha[^;]{0,40}' | head -5
echo "--- 'seg ===' / 'path ===' kaliplari:"
sed -n '28001,32356p' server_container.mjs | grep -coE "=== '[a-z-]+'"

echo
echo "############ 3. EFTAL HATASI TABLOSU — saha_musteri_tedarikci_destek semasi ############"
$PG -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_musteri_tedarikci_destek' ORDER BY ordinal_position;"

echo "############ 4. saha_denetim CANLI MI — 3 kayit ne ############"
$PG -c "SELECT ts::date, eylem, varlik, alanlar FROM saha_denetim ORDER BY ts DESC;"

echo "############ 5. saha_iskonto_talep 0 satir — endpoint var mi, yaziyor mu ############"
grep -n "saha_iskonto_talep" server_container.mjs | head -10
