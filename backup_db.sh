#!/usr/bin/env bash
# Daily encrypted PostgreSQL backup
# Cron: 0 3 * * *  /opt/krb-assessment/backup_db.sh

set -e
source /opt/krb-assessment/.env 2>/dev/null || true

BACKUP_DIR="/opt/backups/derive"
DATE=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="${BACKUP_DIR}/derive_${DATE}.sql.gz"
ENCRYPTED_FILE="${DUMP_FILE}.gpg"

# Retention: keep 30 days of backups
find "$BACKUP_DIR" -name "*.gpg" -mtime +30 -delete

# Dump — use DB creds from environment
PGPASSWORD="${DB_PASSWORD}" pg_dump \
  -h "${DB_HOST:-localhost}" \
  -U "${DB_USER:-assessment_app}" \
  -d "${DB_NAME:-assessment_platform}" \
  --no-owner --no-acl \
  | gzip > "$DUMP_FILE"

# Encrypt with GPG symmetric cipher (set passphrase in BACKUP_PASSPHRASE env var)
if [ -n "$BACKUP_PASSPHRASE" ]; then
  echo "$BACKUP_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
    --symmetric --cipher-algo AES256 \
    --output "$ENCRYPTED_FILE" "$DUMP_FILE"
  rm -f "$DUMP_FILE"
  echo "[backup] ✔ Encrypted backup: $ENCRYPTED_FILE ($(du -sh "$ENCRYPTED_FILE" | cut -f1))"
else
  # No passphrase configured — keep unencrypted but warn loudly
  mv "$DUMP_FILE" "${DUMP_FILE%.gz.gpg}.sql.gz"  2>/dev/null || true
  echo "[backup] ⚠  BACKUP_PASSPHRASE not set — backup is UNENCRYPTED"
fi
