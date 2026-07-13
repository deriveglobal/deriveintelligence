#!/usr/bin/env bash
# Salt okuma. INSERT INTO bi_satis_faturalari YOK. O halde veri NEREDEN giriyor?
# Ve: 5MB limiti gercekten ingest yolunda mi? (satis dosyasi 5,4MB -> RED)
S=/opt/krb-assessment/server_container.mjs

echo "############ 1) ⚠ 5MB LIMITI — ERP yukleme yolunda mi? ############"
grep -n "5 \* 1024 \* 1024\|too large\|413" $S | head
echo "  -- limitin icinde oldugu fonksiyon --"
L=$(grep -n "5 \* 1024 \* 1024" $S | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-25)),$((L-1))p" $S
echo "  ^ Bu fonksiyonu ERP yukleme mi cagiriyor, yoksa baska bir upload mu?"

echo
echo "############ 2) INSERT nerede? (sablonlu olabilir) ############"
grep -n "INSERT INTO \${\|INSERT INTO \" *+\|bi_ingestion_log" $S | head -20
echo "  -- ingestion_log'a yazan fonksiyonun etrafi --"
L=$(grep -n "INSERT INTO bi_ingestion_log" $S | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-70)),$((L+10))p" $S

echo
echo "############ 3) query_type degerleri nerede tanimli? (satis_faturalari vs.) ############"
grep -n "satis_faturalari\|tedarikci_faturalari\|odeme_gecmisi\|stok_durumu\|musteri_bakiye" $S \
  | grep -v "FROM\|JOIN\|CREATE\|INDEX" | head -20

echo
echo "############ 4) ERP yukleme ENDPOINT'i ############"
grep -n "api/bi/.*upload\|api/bi/.*ingest\|/ingest\|uploadErp\|erpUpload" $S | head

echo
echo "############ 5) Yukleme BASARISIZ olunca iz kaliyor mu? ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT * FROM bi_ingestion_log ORDER BY processed_at DESC LIMIT 12;"
echo "  ^ Sadece BASARILI kayitlar varsa: basarisiz yukleme IZ BIRAKMIYOR."
echo "    ERP 31 gundur olu ve kimse fark etmedi -- sebebi bu olabilir."

echo
echo "############ 6) Container loglarinda 413 / too large var mi? ############"
docker logs krb-assessment 2>&1 | grep -i "too large\|413\|ingest\|payload" | tail -20 \
  || echo "  (log yok / donmus)"

echo
echo "############ 7) nginx/proxy body limiti de var mi? ############"
grep -rn "client_max_body_size" /etc/nginx/ 2>/dev/null | head
echo "  ^ nginx varsayilani 1MB. Ayarlanmamissa dosya app'e HIC ULASMIYOR."
