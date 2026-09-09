echo "############ A. COKLU KAYNAK — ayni sayinin kac hesabi var ############"
for kavram in "ciro" "brut\|marj" "stok.*deger\|deger.*stok" "dso\|tahsilat" "sermaye\|yuk"; do
  echo "--- '$kavram' hesaplayan AYRI SQL blok sayisi (FROM iceren):"
  grep -inE "$kavram" server_container.mjs | grep -iE "SELECT|SUM\(|FROM " | grep -c "FROM"
done
echo
echo "--- ciro'yu SUM(satir_tutar) ile hesaplayan farkli satirlar:"
grep -nE "SUM\(satir_tutar\)|sum\(satir_tutar\)" server_container.mjs | wc -l
echo "--- DSO/tahsilat kaynak tablolari (hangi tablodan):"
grep -oE "FROM (bi_fatura_tahsilat|bi_odeme_gecmisi|bi_musteri_risk)" server_container.mjs | sort | uniq -c

echo
echo "############ B. PROMPT'TA RAKAM — TAM TARAMA (ornekleme YOK) ############"
echo "--- statik string icinde para/oran/binlik (yorum haric):"
grep -nE "'[^']*[0-9]+[.,][0-9]+ ?(M|milyon|%|gun|gün|TL)" server_container.mjs \
  | grep -vE "^\s*[0-9]+:\s*(//|--|\*)" \
  | grep -vE "SELECT|WHERE|ROUND|COALESCE|\|\||LIKE|interval|::|GROUP|ORDER" | head -40
echo "--- SAYI (kabaca kalan sabit):"
grep -nE "'[^']*[0-9]+[.,][0-9]+ ?(M|milyon|%|gun|gün|TL)" server_container.mjs \
  | grep -vE "^\s*[0-9]+:\s*(//|--|\*)" \
  | grep -vE "SELECT|WHERE|ROUND|COALESCE|\|\||LIKE|interval|::|GROUP|ORDER" | wc -l

echo
echo "############ C. VERI BUTUNLUGU ############"
PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
echo "--- FK sayisi (kac tablo baska tabloya bagli):"
$PG -t -c "SELECT count(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public';"
echo "--- export_date filtresiz sorgular (en cok kullanilan 3 tablo):"
for t in bi_musteri_risk bi_stok_anlik bi_cari_bakiye; do
  tot=$(grep -c "$t" server_container.mjs)
  exp=$(grep "$t" server_container.mjs | grep -c "export_date")
  echo "  $t: $tot referans / $exp export_date'li"
done
echo "--- en son export_date her ana tabloda:"
$PG -c "SELECT 'satis' t, max(export_date) FROM bi_satis_faturalari UNION ALL SELECT 'risk', max(export_date) FROM bi_musteri_risk UNION ALL SELECT 'stok', max(export_date) FROM bi_stok_anlik UNION ALL SELECT 'cari', max(export_date) FROM bi_cari_bakiye UNION ALL SELECT 'tedarikci', max(export_date) FROM bi_tedarikci_faturalari;"
