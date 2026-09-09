#!/usr/bin/env bash
# TAHSILAT_GUNLUK_V1 — bi_odeme_gecmisi'ni tahsilat.xlsx'ten doldurur (günlük tahsilat grani).
#   erp_ingest ile AYNI yol: dosyayı krb-assessment konteynerine akıt, içeride python3 ile yükle.
#   Konteynerde openpyxl + psycopg2 + DATABASE_URL zaten var (erp_ingest de burada koşuyor).
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY load_odeme_gecmisi.py deploy_odeme_gecmisi.sh tahsilat.xlsx $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_odeme_gecmisi.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
[ -f tahsilat.xlsx ] || { echo "!! tahsilat.xlsx yok — önce scp'le"; exit 1; }
[ -f load_odeme_gecmisi.py ] || { echo "!! load_odeme_gecmisi.py yok"; exit 1; }
TENANT=$(docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -Atc \
  "SELECT id FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1")
echo "tenant=$TENANT"
[ -n "$TENANT" ] || { echo "!! tenant bulunamadı"; exit 1; }
# Betiği /tmp'e koy ve OKUNABİLİR yap (docker cp root-owned bırakıyor → app user okuyamıyor).
docker cp load_odeme_gecmisi.py krb-assessment:/tmp/load_odeme_gecmisi.py
docker exec -u root krb-assessment chmod 644 /tmp/load_odeme_gecmisi.py
echo "===== YÜKLEME ====="
# xlsx'i stdin ile akıt; gerçek çıkış kodunu KORU (rm hatayı maskelemesin).
cat tahsilat.xlsx | docker exec -i krb-assessment sh -c \
  "cat > /tmp/tah.xlsx && python3 /tmp/load_odeme_gecmisi.py /tmp/tah.xlsx '$TENANT'; RC=\$?; rm -f /tmp/tah.xlsx /tmp/load_odeme_gecmisi.py; exit \$RC"
echo "===== DOĞRULAMA ====="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT 'toplam' etiket, count(*)::text adet, round(sum(odenen_tutar))::bigint::text tl FROM bi_odeme_gecmisi WHERE tenant_id='$TENANT'::uuid
   UNION ALL
   SELECT 'dun ('||((now() AT TIME ZONE 'Europe/Istanbul')::date - 1)::text||')', count(*)::text, round(coalesce(sum(odenen_tutar),0))::bigint::text
     FROM bi_odeme_gecmisi WHERE tenant_id='$TENANT'::uuid AND odeme_tarihi=((now() AT TIME ZONE 'Europe/Istanbul')::date - 1);"
echo "[BİTTİ] bi_odeme_gecmisi hazır — artık 'dün tahsil edilen' sorgulanabilir."
