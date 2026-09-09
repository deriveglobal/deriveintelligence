#!/usr/bin/env bash
# Derive · AUTH/USER RECON (SALT-OKUNUR) — rep-login seed'ini uygulamanin KENDI
# auth zinciriyle (users->tenant_users->tenant_user_modules->rep_kimlik_koprusu)
# dogru kurmak icin sema + KRB rep sablonu + hashPassword/verify algoritmasi.
# Hicbir sey yazmaz (psql SELECT + grep/sed).
set -uo pipefail
KRB=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
PSQL(){ docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform "$@"; }

echo "===== 1. users tablosu SEMA ====="
PSQL -c "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position;"

echo "===== 2. tenant_user_modules SEMA ====="
PSQL -c "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='tenant_user_modules' ORDER BY ordinal_position;"

echo "===== 3. KRB BIR saha rep TAM ZINCIR (sifre MASKELI) ====="
echo "--- users (parola alani gizli, sadece bicim) ---"
PSQL -c "SELECT id, email, role, (CASE WHEN password_hash IS NULL THEN 'NULL' ELSE left(password_hash,7)||'…('||length(password_hash)||')' END) AS pw_fmt, created_at::date FROM users WHERE id='bd1787e9-2eb8-415b-9423-af3766f0fab4';" 2>&1 | head -20
echo "--- tenant_users ---"
PSQL -c "SELECT tenant_role, active, created_at::date FROM tenant_users WHERE tenant_id='$KRB' AND user_id='bd1787e9-2eb8-415b-9423-af3766f0fab4';"
echo "--- tenant_user_modules (module_role + permissions_json sekli) ---"
PSQL -c "SELECT module_id, module_role, active, permissions_json FROM tenant_user_modules WHERE tenant_id='$KRB' AND user_id='bd1787e9-2eb8-415b-9423-af3766f0fab4';"
echo "--- rep_kimlik_koprusu ---"
PSQL -c "SELECT sap_temsilci, durum, kanal_etiket FROM rep_kimlik_koprusu WHERE tenant_id='$KRB' AND user_id='bd1787e9-2eb8-415b-9423-af3766f0fab4';"

echo "===== 4. tenant_user_modules module_id/role dagilim (KRB saha rep kalibi) ====="
PSQL -c "SELECT module_id, module_role, count(*) FROM tenant_user_modules WHERE tenant_id='$KRB' GROUP BY 1,2 ORDER BY 1,2;"

echo "===== 5. users role dagilim (rep hangi role) ====="
PSQL -c "SELECT role, count(*) FROM users GROUP BY 1 ORDER BY 2 DESC;"

echo "===== 6. hashPassword + parola dogrulama ALGORITMASI (kaynaktan, birebir kopyalanacak) ====="
echo "--- hashPassword ---"
docker exec krb-assessment grep -n -A18 "hashPassword" /app/server.mjs | head -40
echo "--- parola karsilastirma (verify/compare/scrypt/pbkdf2/bcrypt) ---"
docker exec krb-assessment grep -n -E "verifyPassword|comparePassword|scrypt|pbkdf2|bcrypt|timingSafeEqual" /app/server.mjs | head -25

echo "===== 7. invite ACCEPT handler — yeni kullanici olustururken NE set ediyor (birebir izlenecek) ====="
docker exec krb-assessment grep -n -A30 "invite/accept" /app/server.mjs | head -60

echo "===== AUTH RECON SONU (yazma yok) ====="
