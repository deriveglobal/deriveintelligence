PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ RLS ############"
$PG -c "SELECT count(*) FILTER (WHERE relrowsecurity) AS rls_acik, count(*) FILTER (WHERE NOT relrowsecurity) AS rls_kapali FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r';"

echo "--- tenant_id VAR ama RLS KAPALI (kiraci sizintisi riski):"
$PG -c "SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public' WHERE c.relkind='r' AND NOT c.relrowsecurity AND EXISTS (SELECT 1 FROM information_schema.columns col WHERE col.table_name=c.relname AND col.column_name='tenant_id') AND c.relname NOT LIKE '%yedek%' ORDER BY 1;"

echo
echo "############ krb_audit_logs — CANLI MI ############"
$PG -c "SELECT count(*) AS kayit, min(created_at)::date AS ilk, max(created_at)::date AS son FROM krb_audit_logs;" 2>/dev/null || echo "(tablo yok ya da kolon farkli)"
$PG -c "\d krb_audit_logs" 2>/dev/null | head -12

echo
echo "############ YETKI KAPSAMI — route basina auth var mi ############"
echo "route toplam: $(grep -cE "url\.pathname === '/api/|url\.pathname === \"/api/" server_container.mjs)"
echo "--- 'requireAuth' / 'requireSaha' / 'session' cagrisi sayisi:"
grep -oE "requireAuth\w*|requireSaha\w*|requireBi\w*|getSession\w*" server_container.mjs | sort | uniq -c | sort -rn
