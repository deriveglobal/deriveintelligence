#!/usr/bin/env bash
# DIAG — son duyuru push/inbox dağıtımı: kim aldı, yazan hariç mi, kaç cihaz kayıtlı.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_duyuru_push.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) SON DUYURU ====="
psqlc "SELECT id, yazan_adi, baslik, created_at FROM saha_duyuru WHERE tenant_id='$T'::uuid ORDER BY created_at DESC LIMIT 1;"
echo "===== 2) O DUYURUYA DÜŞEN INBOX (kim aldı) ====="
psqlc "WITH d AS (SELECT id, yazan_id FROM saha_duyuru WHERE tenant_id='$T'::uuid ORDER BY created_at DESC LIMIT 1)
       SELECT u.full_name, b.baslik, b.created_at,
              CASE WHEN b.user_id=(SELECT yazan_id FROM d) THEN '⚠ YAZAN' ELSE '' END not_
         FROM bi_bildirim b JOIN users u ON u.id=b.user_id
        WHERE b.tenant_id='$T'::uuid AND (b.data->>'id')=(SELECT id::text FROM d)
        ORDER BY u.full_name;"
echo "===== 3) INBOX ÖZET (o duyuru) ====="
psqlc "WITH d AS (SELECT id, yazan_id FROM saha_duyuru WHERE tenant_id='$T'::uuid ORDER BY created_at DESC LIMIT 1)
       SELECT count(*) AS inbox_kayit,
              count(*) FILTER (WHERE b.user_id=(SELECT yazan_id FROM d)) AS yazana_dusen
         FROM bi_bildirim b WHERE b.tenant_id='$T'::uuid AND (b.data->>'id')=(SELECT id::text FROM d);"
echo "===== 4) KAYITLI PUSH CİHAZLARI ====="
psqlc "SELECT count(*) AS cihaz, count(DISTINCT user_id) AS kullanici, max(updated_at) AS son_kayit FROM bi_push_token WHERE tenant_id='$T'::uuid;"
echo "===== 5) SON GÖNDERİCİNİN cihazı var mı? ====="
psqlc "WITH d AS (SELECT yazan_id FROM saha_duyuru WHERE tenant_id='$T'::uuid ORDER BY created_at DESC LIMIT 1)
       SELECT u.full_name yazan, count(t.token) cihaz
         FROM d JOIN users u ON u.id=d.yazan_id
         LEFT JOIN bi_push_token t ON t.user_id=d.yazan_id AND t.tenant_id='$T'::uuid
        GROUP BY 1;"
