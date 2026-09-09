#!/usr/bin/env bash
# ZIYARET_CIRO — Wave 1 veri motoru: /api/saha/rapor/ziyaret-ciro (server). UI sekmesi ayrı gelecek.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ziyaret_ciro.sh patch_ziyaret_ciro_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_ciro.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"; T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_ziyaret_ciro_server.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q ZIYARET_CIRO_V1 "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_ziyaret_ciro_server.py "$SRV"
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
  cp "$SRV" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/zc_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/zc_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c ZIYARET_CIRO_V1 /app/server.mjs || true
echo "===== GERÇEK VERİ — Ekip Ziyaret→Ciro (son 90 gün) ====="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c \
 "WITH vis AS (SELECT z.rep_id, z.musteri_id, count(*) ziyaret FROM saha_ziyaret z
                WHERE z.tenant_id='$T'::uuid AND z.durum='TAMAMLANDI' AND z.ziyaret_tarihi >= CURRENT_DATE-90 GROUP BY 1,2),
       enr AS (SELECT v.rep_id, v.ziyaret, m.musteri_kodu,
                      COALESCE((SELECT SUM(f.satir_tutar) FROM bi_satis_faturalari f
                                WHERE f.tenant_id::text='$T' AND f.musteri_kodu=m.musteri_kodu
                                  AND f.fatura_tarihi >= CURRENT_DATE-90),0) ciro
                 FROM vis v JOIN saha_musteri m ON m.id=v.musteri_id)
  SELECT COALESCE(u.full_name,'?') rep, sum(e.ziyaret)::int ziyaret, count(*)::int musteri,
         count(*) FILTER (WHERE e.musteri_kodu IS NOT NULL)::int eslesen,
         round(sum(e.ciro))::bigint ciro,
         CASE WHEN sum(e.ziyaret)>0 THEN round(sum(e.ciro)/sum(e.ziyaret))::bigint END ciro_ziyaret
    FROM enr e LEFT JOIN users u ON u.id=e.rep_id GROUP BY 1 ORDER BY ciro DESC NULLS LAST;"
echo "[BITTI] Ziyaret→Ciro veri motoru canlı. Sonraki adım: 💰 Ciro sekmesi (mobil+masaüstü)."
