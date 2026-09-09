#!/usr/bin/env bash
# YENI_MUSTERI_GERCEK — "Yeni Müşteri" gerçek saha edinimi (ilk ziyaret APP + Excel master değil).
#   Server endpoint + mobil etiket/tooltip. Tek build.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yeni_musteri_gercek.sh patch_yeni_musteri_gercek_server.py patch_yeni_musteri_gercek_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yeni_musteri_gercek.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
SRV=server_container.mjs; MOB=shells/saha.js
for f in "$SRV" "$MOB" patch_yeni_musteri_gercek_server.py patch_yeni_musteri_gercek_mobile.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
pat () { # $1 dosya $2 patch
  if grep -q YENI_MUSTERI_GERCEK_V1 "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 "$2" "$1"
  node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
  case "$1" in *.js) cp "$1" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm $1" || { echo "HATA esm $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; };; esac
}
pat "$SRV" patch_yeni_musteri_gercek_server.py
pat "$MOB" patch_yeni_musteri_gercek_mobile.py
docker build -t krb-assessment:secure . >/tmp/ym_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ym_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server: "; docker exec "$CID" grep -c YENI_MUSTERI_GERCEK_V1 /app/server.mjs || true
echo -n "[dogrula] mobil: ";  docker exec "$CID" grep -c YENI_MUSTERI_GERCEK_V1 /app/shells/saha.js || true
echo "===== YENİ TANIM — gerçek yeni müşteri (tüm zaman) ====="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c \
 "WITH i AS (SELECT z.musteri_id, (array_agg(z.kaynak ORDER BY COALESCE(z.ziyaret_tarihi,z.created_at::date) ASC, z.created_at ASC))[1] ilk_kaynak
             FROM saha_ziyaret z WHERE z.tenant_id='$T'::uuid GROUP BY z.musteri_id)
  SELECT count(*) AS gercek_yeni_musteri
    FROM saha_musteri m JOIN i ON i.musteri_id=m.id
   WHERE m.tenant_id='$T'::uuid AND i.ilk_kaynak='APP' AND COALESCE(m.kayit_kaynagi,'')<>'EXCEL_IMPORT_KONTROL';"
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 'Yeni Müşteri' artık yalnız gerçek saha edinimini sayıyor (toplu yüklemeler hariç)."
