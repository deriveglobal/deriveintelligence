#!/usr/bin/env bash
# DIAG — "Yeni Müşteri" tanımı: müşteri kaynak kırılımı + created_at kümelenmesi + ziyaret kaynağı.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_yeni_musteri.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
psqlc () { docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "$1"; }
echo "===== 1) saha_musteri kaynak kırılımı (kayit_kaynagi) ====="
psqlc "SELECT COALESCE(NULLIF(kayit_kaynagi,''),'(boş/null)') kaynak, count(*) adet,
              min(created_at)::date ilk, max(created_at)::date son,
              count(*) FILTER (WHERE created_by IS NOT NULL) created_by_var
       FROM saha_musteri WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC;"
echo "===== 2) created_at AYLIK kümelenme (import sıçramaları görünür) ====="
psqlc "SELECT to_char(date_trunc('month',created_at),'YYYY-MM') ay, count(*) adet
       FROM saha_musteri WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 1;"
echo "===== 3) ziyaret kaynağı (APP vs EXCEL_MIGRASYON) ====="
psqlc "SELECT COALESCE(kaynak,'(null)') kaynak, count(*) adet, count(DISTINCT musteri_id) musteri
       FROM saha_ziyaret WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC;"
echo "===== 4) APP ziyaretiyle ilk kez tanışılan müşteri (gerçek saha edinimi adayı) ====="
psqlc "WITH ilk AS (
         SELECT musteri_id, min(COALESCE(ziyaret_tarihi, created_at::date)) ilk_ziyaret,
                (array_agg(kaynak ORDER BY COALESCE(ziyaret_tarihi, created_at::date) ASC))[1] ilk_kaynak
         FROM saha_ziyaret WHERE tenant_id='$T'::uuid GROUP BY musteri_id)
       SELECT ilk_kaynak, count(*) musteri, min(ilk_ziyaret) ilk, max(ilk_ziyaret) son
       FROM ilk GROUP BY 1 ORDER BY 2 DESC;"
