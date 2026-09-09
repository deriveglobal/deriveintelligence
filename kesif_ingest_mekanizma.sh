#!/usr/bin/env bash
# ERP INGEST MEKANİZMASI — nasıl yükleniyor, hangi kadans, 5MB nerede kesiyor, invmoving24 ne. READ-ONLY.
# Amaç: manuel-upload hipotezini bi_ingestion_log ile kanıtla; ONAR vs SNAPSHOT çatalını grounded kararlaştır.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
REPO='/opt/krb-assessment'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "A. bi_ingestion_log KOLONLARI"
$PSQL -c "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_ingestion_log';" 2>&1 | sed 's/^/  /'

hr "A2. YÜKLEME GEÇMİŞİ — son 25 kayıt (kadans + mekanizma + durum + boyut/hata)"
$PSQL -x -c "SELECT * FROM bi_ingestion_log ORDER BY 1 DESC LIMIT 25;" 2>&1 | sed 's/^/  /'

hr "B. STOK HAREKET tazeliği — belge_tarihi vs ingested_at (son yükleme batch'i ne zaman girdi)"
$PSQL -c "SELECT max(belge_tarihi)::date son_belge, max(ingested_at) son_ingest, count(*) satir FROM bi_stok_hareket WHERE tenant_id::text='$T';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT ingested_at::date yukleme_gunu, count(*) satir FROM bi_stok_hareket WHERE tenant_id::text='$T' GROUP BY 1 ORDER BY 1 DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "C. ERP INGEST ENDPOINT'İ — bi_ingestion_log'a INSERT eden route + yakınındaki boyut limiti (kod)"
grep -nE "(bi_ingestion_log|/api/(bi|erp)/[a-z-]*(yukle|ingest|import|upload|load)|invmoving|export_date)" \
  "$REPO/server_container.mjs" 2>&1 | head -40 | sed 's/^/  /'

hr "C2. 5MB limitleri kodda TAM YER — hangi endpoint'e ait (ERP mi, assessment mi)"
grep -nE "5 ?\* ?1024 ?\* ?1024|Maximum.*5MB|too large" "$REPO/server_container.mjs" 2>&1 | sed 's/^/  /'

hr "D. MANUEL YÜKLEME SCRIPTLERİ — nasıl çalışıyorlar (ilk 25 satır: curl mu, \\copy mu, hangi dosya)"
for f in erp_yukle.sh erp_yukle_hepsi.sh ingest_kodu_oku.sh; do
  printf -- '--- %s ---\n' "$f"
  head -25 "$REPO/$f" 2>&1
done | sed 's/^/  /'

hr "E. invmoving24 (#100) repo'da GEÇİYOR MU — kaynak export adı mı, koda gömülü mü"
grep -rinE "invmoving" "$REPO" --include='*.sh' --include='*.js' --include='*.mjs' --include='*.md' 2>/dev/null | grep -v derive_arsiv/krb-session-outputs | head -15 | sed 's/^/  /'

hr "BITTI — KİLİT: (A2) yükleme kadansı+mekanizması (manuel upload mu, dosya adı invmoving24 mü, hata/boyut var mı) · (C2) 5MB ERP yolunu mu assessment yolunu mu kesiyor · (D) bir load fiilen nasıl tetikleniyor. → Bunlarla ONAR(5MB kaldır + manuel akışı sürtünmesizleştir) vs SNAPSHOT(cockpit'e geç) çatalını netleştireceğiz."
