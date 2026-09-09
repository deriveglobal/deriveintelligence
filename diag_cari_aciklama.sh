#!/usr/bin/env bash
# DIAG — "ERP cari" kafa karışıklığı: musteri_kodu vs VKN. Kim kimdir, örneklerle.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_cari_aciklama.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) kod × VKN matrisi (kim ERP cari, kimde VKN var) ====="
psqlc "SELECT (musteri_kodu IS NOT NULL AND musteri_kodu<>'') AS erp_kodu_var,
              (vergi_no IS NOT NULL AND vergi_no<>'')       AS vkn_var,
              count(*)
       FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true
       GROUP BY 1,2 ORDER BY 1 DESC,2 DESC;"
echo "===== 2) ÖRNEK: ERP kodu VAR ama VKN YOK (bunlar 'ERP cari'ye bağlı) ====="
psqlc "SELECT firma, musteri_kodu, kayit_kaynagi, durum FROM saha_musteri
       WHERE tenant_id='$T'::uuid AND aktif=true AND musteri_kodu IS NOT NULL AND musteri_kodu<>''
         AND (vergi_no IS NULL OR vergi_no='') ORDER BY firma LIMIT 10;"
echo "===== 3) Bu kodlar master_musteri'de (ERP) gerçekten var mı? ====="
psqlc "SELECT count(*) saha_kodlu,
              count(*) FILTER (WHERE EXISTS (SELECT 1 FROM master_musteri mm WHERE mm.tenant_id='$T'::uuid AND mm.musteri_kodu=m.musteri_kodu)) master_de_var
       FROM saha_musteri m WHERE m.tenant_id='$T'::uuid AND m.aktif=true AND m.musteri_kodu IS NOT NULL AND m.musteri_kodu<>'';"
echo "===== 4) 'ERP cari' gibi bir ETİKET var mı? (kayit_kaynagi değerleri) ====="
psqlc "SELECT COALESCE(NULLIF(kayit_kaynagi,''),'(boş)') kaynak, count(*),
              count(*) FILTER (WHERE musteri_kodu IS NOT NULL AND musteri_kodu<>'') kodlu
       FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true GROUP BY 1 ORDER BY 2 DESC;"
echo "===== 5) eşleşmemişlerin İSİM ile ERP'de karşılığı (oto-eşleşme potansiyeli) ====="
psqlc "WITH s AS (SELECT DISTINCT lower(regexp_replace(trim(firma),'\s+',' ','g')) nf
                  FROM saha_musteri WHERE tenant_id='$T'::uuid AND aktif=true AND (musteri_kodu IS NULL OR musteri_kodu=''))
       SELECT (SELECT count(*) FROM s) eslesmemis,
              (SELECT count(*) FROM s WHERE EXISTS (SELECT 1 FROM master_musteri mm WHERE mm.tenant_id='$T'::uuid AND lower(regexp_replace(trim(mm.musteri_adi),'\s+',' ','g'))=s.nf)) isimle_bulunur;"
