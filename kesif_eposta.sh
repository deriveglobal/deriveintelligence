#!/usr/bin/env bash
# E-posta gönderim mekanizması keşfi — nabiz digest'i hangi yolla yollarım (Graph/SMTP). OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. Gönderim fonksiyonu (Graph mı SMTP mi)"
grep -noE "async function [a-zA-Z_]*[Mm]ail[a-zA-Z_]*|async function [a-zA-Z_]*[Ee]posta[a-zA-Z_]*|async function send[A-Za-z]*|function [a-zA-Z_]*sendEmail" server_container.mjs | head | sed 's/^/  /'
grep -noiE "graph.microsoft.com|nodemailer|createTransport|smtp|/sendMail" server_container.mjs | head | sed 's/^/  /'

hr "2. En çok kullanılan gönderim fonksiyonunun imzası + gövde başı"
L=$(grep -nE "async function .*[Mm]ail|async function .*[Ee]posta" server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L)),$((L+22))p" server_container.mjs | sed 's/^/  /'

hr "3. Bir çağrı örneği (nasıl çağrılıyor: alıcı, konu, içerik)"
grep -noE "await [a-zA-Z_]*[Mm]ail[a-zA-Z_]*\(|await [a-zA-Z_]*[Ee]posta[a-zA-Z_]*\(|sendMail\(|sendEmail\(" server_container.mjs | head | sed 's/^/  /'

hr "4. Fatih'in e-postası sistemde nerede (alıcı için)"
grep -noiE "fatyil977|fatih|owner_email|admin_email|consult@deriveglobal" server_container.mjs | head | sed 's/^/  /'
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT email, ad_soyad FROM platform_users WHERE lower(email) LIKE '%fat%' OR rol ILIKE '%owner%' LIMIT 5;" 2>&1 | sed 's/^/  /'

hr "BITTI"
