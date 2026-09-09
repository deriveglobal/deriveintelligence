#!/usr/bin/env bash
# DERIVE_DB_BACKUP_V1 — gunluk DB yedek. Bos/kirik yedek URETMEZ; hata olursa GURULTU + log.
set -uo pipefail
TS="$(date -u +%Y%m%d)"; OUT="/opt/backups/derive/db_${TS}.sql.gz.gpg"
LOG="/var/log/derive_backup.log"; MIN=1000000
PP="$(grep -E '^BACKUP_PASSPHRASE=' /opt/krb-assessment/.env | cut -d= -f2-)"
[ -z "${PP:-}" ] && { echo "[$(date -u +%FT%TZ)] HATA: BACKUP_PASSPHRASE yok — yedek YOK" >>"$LOG"; exit 1; }
mkdir -p /opt/backups/derive; TMP="$(mktemp)"
if docker exec krb-assessment-postgres pg_dump -U assessment_app assessment_platform \
   | gzip -9 \
   | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 --symmetric -o "$TMP" 3< <(printf '%s' "$PP"); then
  SZ=$(stat -c%s "$TMP" 2>/dev/null||echo 0)
  if [ "$SZ" -ge "$MIN" ]; then
    mv "$TMP" "$OUT"; echo "[$(date -u +%FT%TZ)] OK: $OUT ($SZ byte)" >>"$LOG"
    find /opt/backups/derive -name 'db_*.sql.gz.gpg' -mtime +14 -delete
  else rm -f "$TMP"; echo "[$(date -u +%FT%TZ)] HATA: boyut $SZ (<$MIN) SUPHELI, yazilmadi" >>"$LOG"; exit 2; fi
else rm -f "$TMP"; echo "[$(date -u +%FT%TZ)] HATA: pg_dump/gpg zinciri patladi" >>"$LOG"; exit 3; fi
