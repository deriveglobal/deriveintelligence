#!/usr/bin/env bash
# DENETIM_113B — bi_ayar yapisi (esik oraya) + gunluk ozet cron calisiyor mu. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_ayar — KOLON YAPISI (key-value mi, columnar mi?)"
$PSQL -c "\d bi_ayar"
echo "--- mevcut icerik ---"
$PSQL -c "SELECT * FROM bi_ayar LIMIT 20;" 2>&1 | sed 's/^/  /'

hr "2. Gunluk ozet CRON'da mi? (calisiyorsa singles oraya akabilir)"
crontab -l 2>/dev/null | grep -iE "gunluk-ozet|gunluk_ozet|saha.*ozet|31553" | sed 's/^/  /' || echo "  (crontab'da gunluk-ozet yok — cron disi tetikleniyor olabilir)"
echo "--- /api/saha/gunluk-ozet endpoint auth/tetikleme (31553 civari) ---"
sed -n '31553,31566p' /opt/krb-assessment/server_container.mjs | nl -ba -v31553 | sed 's/^/  /'

hr "3. saha_sinyal — son 24s onem dagilimi (onem=3 ne siklikta uretiliyor?)"
$PSQL -c "
SELECT onem, count(*) FILTER (WHERE created_at > now()-interval '7 days') AS son_7gun,
       count(*) AS toplam
  FROM saha_sinyal GROUP BY 1 ORDER BY 1 DESC;" 2>&1 | sed 's/^/  /'
echo "--- owner_bildirildi kac kez TRUE (kac e-posta gitti)? ---"
$PSQL -c "SELECT owner_bildirildi, count(*) FROM saha_sinyal GROUP BY 1;" 2>&1 | sed 's/^/  /'

hr "4. _ownerAlarmEmail — kime gidiyor?"
grep -nE "_ownerAlarmEmail|ownerAlarmEmail" /opt/krb-assessment/server_container.mjs | head -3 | sed 's/^/  /'
LN=$(grep -nE "function _ownerAlarmEmail|_ownerAlarmEmail *=" /opt/krb-assessment/server_container.mjs | head -1 | cut -d: -f1)
[ -n "${LN:-}" ] && sed -n "${LN},$((LN+12))p" /opt/krb-assessment/server_container.mjs | sed 's/^/  /'

hr "BITTI — esik bi_ayar'a nasil yazilacagini bu ciktidan bilecegim"
