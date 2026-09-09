echo "############ A. SESSIZ CATCH — hata yutan bloklar ############"
echo "--- tamamen bos: catch {} / catch (e) {}"
grep -nE "catch\s*(\([a-z_]*\))?\s*\{\s*\}" server_container.mjs | head -40
echo "--- SAYI:"
grep -cE "catch\s*(\([a-z_]*\))?\s*\{\s*\}" server_container.mjs

echo
echo "--- catch var ama console'a HIC yazmiyor (3 satir icinde log yok)"
grep -A3 -nE "\} catch" server_container.mjs | grep -B1 -A2 "catch" | grep -c "console" 
echo "   toplam catch:"
grep -cE "\} catch" server_container.mjs
echo "   console iceren catch (kabaca):"
grep -A2 -E "\} catch" server_container.mjs | grep -c "console"

echo
echo "############ B. YETKI — hangi uc korumasiz ############"
echo "--- auth/session kontrolu iceren satir sayisi:"
grep -cE "requireAuth|session\?\.|!session|session\.userId|gereken_yetki|checkPerm|hasModule" server_container.mjs
echo
echo "--- /api/ ile baslayip AYNI satirda auth gecmeyen route'lar (ilk 30):"
grep -nE "url\.pathname === '/api/" server_container.mjs | head -30

echo
echo "############ C. RLS — hangi tabloda satir guvenligi acik ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT count(*) FILTER (WHERE relrowsecurity) AS rls_acik,
       count(*) FILTER (WHERE NOT relrowsecurity) AS rls_kapali
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r';"
echo "--- tenant_id'si OLAN ama RLS'i KAPALI tablolar (sizinti riski):"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT c.relname
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
 WHERE c.relkind='r' AND NOT c.relrowsecurity
   AND EXISTS (SELECT 1 FROM information_schema.columns col
                WHERE col.table_name=c.relname AND col.column_name='tenant_id')
   AND c.relname NOT LIKE '%yedek%'
 ORDER BY 1;"
