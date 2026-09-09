#!/usr/bin/env bash
# VKN_BACKFILL — kod'lu saha müşterilerinin boş VKN'sini SAP'ten (master_musteri) doldur.
#   YALNIZ boş olanı doldurur (idempotent, geri-dönülebilir mantık: mevcut VKN'ye dokunmaz).
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_vkn_backfill.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== ÖNCE: VKN dolu saha müşterisi ====="
psqlc "SELECT count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'') vkn_dolu, count(*) toplam FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true;"
echo "===== BACKFILL (boş VKN ← SAP master_musteri.vergi_no, kod ile) ====="
psqlc "UPDATE saha_musteri s
       SET vergi_no = mm.vergi_no, updated_at = now()
       FROM master_musteri mm
       WHERE s.tenant_id='$T'::uuid AND s.aktif=true
         AND s.musteri_kodu IS NOT NULL AND s.musteri_kodu<>''
         AND (s.vergi_no IS NULL OR s.vergi_no='')
         AND mm.tenant_id=s.tenant_id AND mm.musteri_kodu=s.musteri_kodu
         AND mm.vergi_no IS NOT NULL AND mm.vergi_no<>'';"
echo "===== SONRA: VKN dolu saha müşterisi ====="
psqlc "SELECT count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'') vkn_dolu, count(*) toplam FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true;"
echo "[BITTI] Boş VKN'ler SAP'ten dolduruldu (kod'lu olanlar). Rapor/eşleştirme için hazır."
