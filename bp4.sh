echo "=== ODEME UCLUSU — kod nerede kullaniyor ==="
echo "--- bi_odeme_gecmisi:"
grep -n "bi_odeme_gecmisi" server_container.mjs erp_ingest.py
echo "--- bi_fatura_tahsilat:"
grep -n "bi_fatura_tahsilat" server_container.mjs erp_ingest.py | head -6
echo "--- bi_musteri_risk_odeme (olu?):"
grep -rn "bi_musteri_risk_odeme" . --include=*.mjs --include=*.py --include=*.js --include=*.sh 2>/dev/null | grep -v node_modules | head -5

echo
echo "=== DENETIM TABLOLARI — gercekten yazan yok mu ==="
for t in security_audit_log security_events audit_events login_attempt_log ip_blocks; do
  echo "  $t: $(grep -rc "$t" server_container.mjs) referans (server_container.mjs)"
done

echo
echo "=== GORUNUMLER — tanimlari (koprü olanlar) ==="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT viewname FROM pg_views WHERE schemaname='public' ORDER BY 1;"
