#!/usr/bin/env bash
# DIAG — musteri_kodu olan saha müşterisinin VKN'si SAP'te (master_musteri) hazır mı? (geri-doldurulabilir)
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_vkn_from_sap.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) kod'lu saha müşterisi → SAP'te VKN hazır mı ====="
psqlc "SELECT count(*) saha_kodlu,
              count(*) FILTER (WHERE mm.vergi_no IS NOT NULL AND mm.vergi_no<>'') sapte_vkn_var,
              count(*) FILTER (WHERE (m.vergi_no IS NULL OR m.vergi_no='') AND mm.vergi_no IS NOT NULL AND mm.vergi_no<>'') geri_doldurulabilir
       FROM saha_musteri m
       LEFT JOIN master_musteri mm ON mm.tenant_id=m.tenant_id AND mm.musteri_kodu=m.musteri_kodu
       WHERE m.tenant_id='$T'::uuid AND m.aktif=true AND m.musteri_kodu IS NOT NULL AND m.musteri_kodu<>'';"
echo "===== 2) ÖRNEK: saha VKN boş → SAP'te dolu ====="
psqlc "SELECT m.firma, m.musteri_kodu, COALESCE(NULLIF(m.vergi_no,''),'(boş)') saha_vkn, mm.vergi_no sap_vkn
       FROM saha_musteri m JOIN master_musteri mm ON mm.tenant_id=m.tenant_id AND mm.musteri_kodu=m.musteri_kodu
       WHERE m.tenant_id='$T'::uuid AND m.aktif=true AND (m.vergi_no IS NULL OR m.vergi_no='')
         AND mm.vergi_no IS NOT NULL AND mm.vergi_no<>'' ORDER BY m.firma LIMIT 8;"
