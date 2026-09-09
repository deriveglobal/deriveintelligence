#!/usr/bin/env bash
# Metrik geçmişi + MARJ ATOMU — GÜNLÜK. TEK KAYNAK fonksiyonlar (yükleme akışı da aynısını çağırır).
# TAZELIK_HONEST_V1: psql -v ON_ERROR_STOP=1 + exit-code kontrolu -> SESSIZ basarisizlik yok.
#   Hata olursa "tamam" DEGIL "HATA" yazar + bi_insa_gunlugu'na TAZELIK_ALARM dusurur (tazelik bekcisi + CEO asistani gorur).
set -uo pipefail
TS="$(date '+%F %T')"
DEXEC="docker exec -i krb-assessment-postgres psql -v ON_ERROR_STOP=1 -U assessment_app -d assessment_platform"

if $DEXEC <<'SQL'
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT tenant_id::text::uuid AS t FROM bi_satis_faturalari LOOP
    PERFORM metrik_snapshot_al(r.t);
    PERFORM metrik_marj_atom_uret(r.t);
  END LOOP;
END $$;
SQL
then
  echo "[$TS] OK: snapshot + marj atomu tamam (tum kiraci)"
else
  RC=$?
  echo "[$TS] HATA: snapshot/atom BASARISIZ (exit $RC) — atom/trend TAZELENMEDI"
  # alarmi gorunur birak (tazelik bekcisi + CEO asistani okur); gunde bir kez
  docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
    "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) SELECT 'TAZELIK_ALARM','metrik_snapshot_gunluk BASARISIZ ('||to_char(now(),'YYYY-MM-DD')||')','gunluk atom/snapshot cron hata dondu; atom/trend tazelenmedi','{\"kaynak\":\"metrik_snapshot_gunluk.sh\",\"exit\":$RC}'::jsonb WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim LIKE 'TAZELIK_ALARM%' AND ts::date=CURRENT_DATE AND detay->>'kaynak'='metrik_snapshot_gunluk.sh')" >/dev/null 2>&1 || true
  exit $RC
fi
