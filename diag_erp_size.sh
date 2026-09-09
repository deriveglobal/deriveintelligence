#!/usr/bin/env bash
# DIAG — ERP tarafı gerçekte ne kadar büyük + saha↔ERP alternatif eşleşme anahtarları (isim/kod).
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_erp_size.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) ERP müşteri evreni (master_musteri) ====="
psqlc "SELECT count(*) master_musteri, count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'') vkn_dolu FROM master_musteri WHERE tenant_id='$T'::uuid;"
echo "===== 2) ERP satış faturalarındaki farklı müşteri ====="
psqlc "SELECT count(DISTINCT musteri_kodu) farkli_kod, count(DISTINCT vergi_no) FILTER (WHERE vergi_no<>'') farkli_vkn FROM bi_satis_faturalari WHERE tenant_id::text='$T';"
echo "===== 3) saha_musteri alternatif anahtar doluluk ====="
psqlc "SELECT count(*) saha, count(*) FILTER (WHERE musteri_kodu IS NOT NULL AND musteri_kodu<>'') kod_dolu, count(*) FILTER (WHERE vergi_no IS NOT NULL AND vergi_no<>'') vkn_dolu FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true;"
echo "===== 4) İSİM ile potansiyel eşleşme (saha.firma ↔ master_musteri) ====="
psqlc "WITH s AS (SELECT DISTINCT lower(regexp_replace(trim(firma),'\s+',' ','g')) nf FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true),
            e AS (SELECT DISTINCT lower(regexp_replace(trim(COALESCE(musteri_adi,firma)),'\s+',' ','g')) nf FROM master_musteri WHERE tenant_id='$T'::uuid)
       SELECT (SELECT count(*) FROM s) saha_isim, (SELECT count(*) FROM s JOIN e USING(nf)) tam_isim_eslesme;"
echo "===== 5) master_musteri kolonları (isim alanı doğrulama) ====="
psqlc "SELECT column_name FROM information_schema.columns WHERE table_name='master_musteri' AND column_name IN ('firma','musteri_adi','unvan','vergi_no','musteri_kodu') ORDER BY 1;"
