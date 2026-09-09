#!/usr/bin/env bash
# Snapshot cron'un TAM ne çalıştırdığı + snapshot fonksiyonları + yukle endpoint hook noktası. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. cron script — metrik_snapshot_gunluk.sh (tam)"
find / -name 'metrik_snapshot_gunluk.sh' 2>/dev/null | head -3
F=$(find / -name 'metrik_snapshot_gunluk.sh' 2>/dev/null | head -1)
[ -n "$F" ] && cat "$F" | sed 's/^/  /' || echo "  (bulunamadı — crontab'a bak)"

hr "2. crontab — snapshot satırı"
crontab -l 2>/dev/null | grep -iE "snapshot|metrik" | sed 's/^/  /' || echo "  (root crontab yok)"
docker exec krb-assessment sh -c 'crontab -l 2>/dev/null' | grep -iE "snapshot|metrik" | sed 's/^/  /' || true

hr "3. snapshot ile ilgili DB fonksiyonları (metrik_*, snapshot)"
$PSQL -c "SELECT proname FROM pg_proc WHERE proname ~* 'metrik|snapshot' ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "4. yukle endpoint — guard hook civarı (snapshot çağrısını buraya ekleyeceğim)"
grep -n "veri_saglik_kapisi\|sonuc.ok\|tazelenen\|execFile.*erp_ingest\|turet" server_container.mjs | head -15 | sed 's/^/  /'

hr "5. yukle endpoint sonuç bloğu (guard hook tam bağlam)"
START=$(grep -n "veri_saglik_kapisi" server_container.mjs | head -1 | cut -d: -f1)
[ -n "$START" ] && sed -n "$((START-12)),$((START+18))p" server_container.mjs

hr "BITTI"
