#!/bin/bash
# backup_all.sh — tüm uygulama dosyalarını yedekler
set -e

TS=$(date +%Y%m%d_%H%M)
BDIR="/opt/krb-assessment/backups/app_${TS}"
mkdir -p "$BDIR"

echo "=== KRB Uygulama Yedeği — $TS ==="
echo "Hedef: $BDIR"

# 1. Host dosyaları
for f in server.mjs app.js; do
  if [ -f "/opt/krb-assessment/$f" ]; then
    cp "/opt/krb-assessment/$f" "$BDIR/$f"
    echo "✓ $f ($(wc -l < /opt/krb-assessment/$f) satır)"
  fi
done

# 2. Container dosyalarını host'a çek, sonra yedekle
for f in index.html shells/bi.js shells/saha.js shells/field-rep.js; do
  DEST="$BDIR/$(basename $f)"
  docker cp "krb-assessment:/app/$f" "$DEST" 2>/dev/null && \
    echo "✓ $f (container, $(wc -l < $DEST) satır)" || \
    echo "✗ $f — container'da bulunamadı"
done

# 3. Patcher'ları da yedekle
PDIR="$BDIR/patchers"
mkdir -p "$PDIR"
for p in /opt/krb-assessment/*.mjs /opt/krb-assessment/*.sh; do
  [ -f "$p" ] && cp "$p" "$PDIR/" && echo "✓ patcher: $(basename $p)"
done

# 4. Özet
echo ""
echo "=== TAMAMLANDI ==="
du -sh "$BDIR"
ls -la "$BDIR/"
