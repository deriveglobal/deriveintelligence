#!/usr/bin/env bash
# OMURGA 39 — cron'a marj atomu ekle (snapshot loop'una). Eski yedeklenir.
set -uo pipefail
F=/opt/krb-assessment/metrik_snapshot_gunluk.sh
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp "$F" "${F}.bak.$(date +%s)" && echo "  ✅"

hr "2. YENİDEN YAZ — snapshot + marj atomu tek loop"
cat > "$F" <<'SH'
#!/usr/bin/env bash
# Metrik geçmişi + MARJ ATOMU — GÜNLÜK. TEK KAYNAK fonksiyonlar (yükleme akışı da aynısını çağırır).
set -u
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL'
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT tenant_id::text::uuid AS t FROM bi_satis_faturalari LOOP
    PERFORM metrik_snapshot_al(r.t);
    PERFORM metrik_marj_atom_uret(r.t);
  END LOOP;
END $$;
SQL
echo "[$(date '+%F %T')] snapshot + marj atomu tamam (tum kiraci)"
SH
chmod +x "$F"
echo "  ✅ DRY: snapshot + atom"

hr "3. TEST — cron'u çalıştır (atom da dolmalı)"
bash "$F" 2>&1 | sed 's/^/  /'
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
  "SELECT count(*) atom_satir, max(hesaplanma_at)::timestamp(0) son FROM bi_marj_atom WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid;" 2>&1 | sed 's/^/  /'

hr "BITTI — cron artık atomu da tazeliyor."
