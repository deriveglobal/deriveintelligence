echo "############ PROMPT SABITLERI — GENIS KAPI, elle suzecegiz ############"
echo "### KRB_COMPANY_PROFILE + DB_SCHEMA + rol promptlari nerede:"
grep -nE "KRB_COMPANY_PROFILE|DB_SCHEMA =|const.*PROFILE|systemPrompt \+=|BILINEN_SORUNLAR" server_container.mjs | head

echo
echo "### string icinde HERHANGI bir rakam iceren prompt satirlari"
echo "### (yorum haric, SQL anahtar kelime haric) — HAM, filtrelemeden:"
awk '
  /^\s*(\/\/|--|\*)/ { next }
  /'"'"'.*[0-9].*'"'"'/ {
    if ($0 ~ /SELECT|WHERE|ROUND|COALESCE|interval|::text|::uuid|::numeric|LIMIT|GROUP BY|ORDER BY|VALUES|INSERT|UPDATE|CREATE|idx_|otpauth/) next
    if ($0 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2}|toLocaleDateString|Date\(|getFullYear|\.[0-9]+p\b/) next
    print NR": "$0
  }
' server_container.mjs | grep -E "%[0-9]|[0-9]+[.,][0-9]|[0-9]{2}\.[0-9]{3}|adet.*[0-9]{4}|~[0-9]|₺[0-9]|[0-9]+ ?(M|gun|gün) " | head -40
