PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. ISKONTO akisi — saha_iskonto_talep'e yazan uc + durum hesabi ############"
grep -n 'INSERT INTO saha_iskonto_talep\|path === "/api/saha/iskonto' server_container.mjs | head

echo
echo "############ 2. DURUM nasil hesaplaniyor — saha_musteri_durum_yenile ############"
grep -n "saha_musteri_durum_yenile\|son_fatura" server_container.mjs | head -8
$PG -c "SELECT prosrc FROM pg_proc WHERE proname='saha_musteri_durum_yenile';" 2>/dev/null | head -30

echo
echo "############ 3. TEXT/UUID JOIN RISKI — saha_musteri_tedarikci_destek nasil sorgulanıyor ############"
grep -n "saha_musteri_tedarikci_destek" server_container.mjs | head

echo
echo "############ 4. saha_ziyaret durum dagilimi (veri mantik kontrolu) ############"
$PG -c "SELECT durum, count(*) FROM saha_ziyaret GROUP BY durum ORDER BY 2 DESC;"
echo "--- ziyaret_tarihi dolu ama durum PLANLANDI olan (celiski) var mi:"
$PG -c "SELECT count(*) FROM saha_ziyaret WHERE ziyaret_tarihi IS NOT NULL AND durum='PLANLANDI';"
