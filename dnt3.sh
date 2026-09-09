PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ KAC KIRACI VAR — RLS'in ciddiyeti buna bagli ############"
$PG -c "SELECT id, name, created_at::date FROM platform_tenants ORDER BY created_at;" 2>/dev/null \
  || $PG -c "SELECT count(*) FROM platform_tenants;"
echo "--- kullanici sayisi / kiraci:"
$PG -c "SELECT t.name, count(u.id) AS kullanici FROM platform_tenants t LEFT JOIN tenant_users u ON u.tenant_id=t.id GROUP BY 1 ORDER BY 2 DESC;" 2>/dev/null || echo "(tenant_users semasi farkli)"

echo
echo "############ krb_audit_logs — DOGRU KOLONLA ############"
$PG -c "SELECT count(*) AS kayit, min(timestamp)::date AS ilk, max(timestamp)::date AS son FROM krb_audit_logs;"
$PG -c "SELECT action, count(*) FROM krb_audit_logs GROUP BY 1 ORDER BY 2 DESC LIMIT 10;"

echo
echo "############ AUTH'SUZ ROUTE — her route'un 15 satir icinde auth cagrisi var mi ############"
awk '
  /url\.pathname === .\/api\// { rt=$0; ln=NR; look=15; next }
  look>0 {
    if (/requireAuth|requireSahaAccess|requireBiDept|getSessionUser|session\.|_ops_ok|secret/) { look=0; next }
    look--
    if (look==0) { print "  AUTH YOK? satir " ln ": " rt }
  }
' server_container.mjs | head -25
