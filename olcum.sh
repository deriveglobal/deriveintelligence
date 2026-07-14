PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. tenant_id — HANGİ AYRIM NE VERİYOR ############"
$PG -c "
SELECT CASE c.relkind WHEN 'r' THEN 'TABLO' WHEN 'v' THEN 'GORUNUM' END AS nesne,
       CASE WHEN c.relname LIKE '%yedek%' THEN 'yedek' ELSE 'canli' END   AS tur,
       col.data_type, count(*)
  FROM information_schema.columns col
  JOIN pg_class c ON c.relname = col.table_name
  JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname='public'
 WHERE col.column_name = 'tenant_id' AND col.table_schema='public'
   AND c.relkind IN ('r','v')
 GROUP BY 1,2,3 ORDER BY 1,2,3;"

echo "--- TEK RAKAM: canli TABLOLAR (yedek yok, gorunum yok)"
$PG -t -c "
SELECT col.data_type || ': ' || count(*)
  FROM information_schema.columns col
  JOIN pg_class c ON c.relname=col.table_name
  JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
 WHERE col.column_name='tenant_id' AND col.table_schema='public'
   AND c.relkind='r' AND c.relname NOT LIKE '%yedek%'
 GROUP BY col.data_type;"

echo
echo "############ 2. GENİŞ KAPI: prompt/string icinde KALAN her rakam ############"
echo "--- para (12,3M / 121,76 M TL / 318,95M)"
grep -nE "[0-9]+[.,][0-9]+ ?M( TL)?\b" server_container.mjs | grep -vE "^\s*[0-9]+:\s*(//|--|\*)" | head -20
echo "--- oran (~%42.5, %8,3)"
grep -nE "~?%[0-9]+[.,]?[0-9]*" server_container.mjs | grep -vE "^\s*[0-9]+:\s*(//|--|\*)" | grep -viE "SELECT|WHERE|ROUND|LIKE '%|\|\|" | head -20
echo "--- gun araligi (59-87 gun, ~68-84)"
grep -nE "[0-9]+-[0-9]+ ?(gun|gün)" server_container.mjs | head -10
echo "--- kur (USD ~46, ₺53)"
grep -nE "₺[0-9]|USD ~|EUR ~" server_container.mjs | head -10
echo "--- binlik sayi (16.996 / 364.785 / 38.604)"
grep -nE "'[^']*[0-9]{1,3}\.[0-9]{3}[^']*'" server_container.mjs | grep -vE "^\s*[0-9]+:\s*(//|--)" | head -20

echo
echo "############ 3. PROMPT SABİTLERİ ÖZET ############"
echo "yorum satirlarindaki rakamlar SAYILMADI (kullaniciya gitmez)."
