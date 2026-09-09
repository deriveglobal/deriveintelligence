#!/usr/bin/env bash
# DIAG — saha müşteri ↔ ERP (VKN) eşleşme oranı: ciro raporları ne kadarını kapsar?
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_vkn_match.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) saha_musteri VKN doluluk ====="
psqlc "SELECT count(*) toplam, count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'') vkn_dolu,
              round(100.0*count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'')/nullif(count(*),0),1) yuzde
       FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true;"
echo "===== 2) VKN ile ERP satışında eşleşen saha müşterisi ====="
psqlc "WITH sm AS (SELECT DISTINCT vergi_no FROM saha_musteri WHERE tenant_id='$T'::uuid AND vergi_no IS NOT NULL AND vergi_no<>'')
       SELECT count(*) saha_vkn, count(*) FILTER (WHERE EXISTS (SELECT 1 FROM bi_satis_faturalari f WHERE f.tenant_id::text='$T' AND f.vergi_no=sm.vergi_no)) erp_de_var
       FROM sm;"
echo "===== 3) ziyaret edilen müşterilerin ERP cirosuyla eşleşmesi (son 90 gün) ====="
psqlc "WITH ziy AS (SELECT DISTINCT m.id, m.vergi_no FROM saha_ziyaret z JOIN saha_musteri m ON m.id=z.musteri_id
                    WHERE z.tenant_id='$T'::uuid AND z.durum='TAMAMLANDI' AND COALESCE(z.ziyaret_tarihi,z.created_at::date) >= (CURRENT_DATE - 90))
       SELECT count(*) ziyaret_edilen, count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'') vkn_var,
              count(*) FILTER (WHERE EXISTS (SELECT 1 FROM bi_satis_faturalari f WHERE f.tenant_id::text='$T' AND f.vergi_no=ziy.vergi_no)) erp_eslesme
       FROM ziy;"
