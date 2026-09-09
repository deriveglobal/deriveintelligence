#!/usr/bin/env bash
# DIAG — Fatih Bilen'in ziyaret yorumlari: kaç yorum, kaç ziyaret, kaç sahip, tarih aralığı.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_fbilen_yorum.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) 'bilen' eşleşen kullanıcılar ====="
psqlc "SELECT id, full_name, email FROM users WHERE full_name ILIKE '%bilen%' OR email ILIKE '%bilen%';"
echo "===== 2) Fatih Bilen yorum özeti ====="
psqlc "WITH fb AS (SELECT id FROM users WHERE full_name ILIKE '%fatih%bilen%' OR full_name ILIKE '%bilen%fatih%' ORDER BY full_name LIMIT 1)
       SELECT count(*) AS yorum_adedi,
              count(DISTINCT y.ziyaret_id) AS ziyaret_adedi,
              count(DISTINCT z.rep_id) AS sahip_adedi,
              count(DISTINCT z.rep_id) FILTER (WHERE z.rep_id <> (SELECT id FROM fb)) AS bildirilecek_sahip,
              min(y.created_at)::date AS ilk, max(y.created_at)::date AS son
         FROM saha_ziyaret_yorum y
         JOIN saha_ziyaret z ON z.id = y.ziyaret_id
        WHERE y.user_id = (SELECT id FROM fb);"
echo "===== 3) Sahip başına kaç ziyaret (Fbilen yorumlu) ====="
psqlc "WITH fb AS (SELECT id FROM users WHERE full_name ILIKE '%fatih%bilen%' OR full_name ILIKE '%bilen%fatih%' ORDER BY full_name LIMIT 1)
       SELECT u.full_name AS rep, count(DISTINCT y.ziyaret_id) AS ziyaret
         FROM saha_ziyaret_yorum y
         JOIN saha_ziyaret z ON z.id = y.ziyaret_id
         LEFT JOIN users u ON u.id = z.rep_id
        WHERE y.user_id = (SELECT id FROM fb) AND z.rep_id <> (SELECT id FROM fb)
        GROUP BY 1 ORDER BY 2 DESC;"
