#!/usr/bin/env bash
# OMURGA 22b — cron'u DRY'la: tek kaynak metrik_snapshot_al. Eski yedeklenir (geri-dönülebilir).
set -uo pipefail
F=/opt/krb-assessment/metrik_snapshot_gunluk.sh
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK — eski cron script"
cp "$F" "${F}.bak.$(date +%s)" && echo "  ✅ yedek: ${F}.bak.*"

hr "2. YENİDEN YAZ — metrik_snapshot_al(tenant) çağıran ince cron"
cat > "$F" <<'SH'
#!/usr/bin/env bash
# Metrik geçmişi — GÜNLÜK SNAPSHOT. TEK KAYNAK: metrik_snapshot_al(tenant) [omurga_22].
# ⚠ Yükleme akışı da AYNI fonksiyonu çağırır → cron ve upload ASLA ayrışmaz.
set -u
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL'
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT tenant_id::text::uuid AS t FROM bi_satis_faturalari LOOP
    PERFORM metrik_snapshot_al(r.t);
  END LOOP;
END $$;
SQL
echo "[$(date '+%F %T')] metrik snapshot tamam (metrik_snapshot_al · tum kiraci)"
SH
chmod +x "$F"
echo "  ✅ DRY'landı"

hr "3. YENİ İÇERİK"
cat "$F" | sed 's/^/  /'

hr "4. TEST — cron'u şimdi çalıştır (ON CONFLICT UPDATE, zararsız)"
bash "$F" 2>&1 | sed 's/^/  /'

hr "BITTI — cron & yükleme artık tek fonksiyonu çağırıyor. Sonra: docker build (server hook için)."
