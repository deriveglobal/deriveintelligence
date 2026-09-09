#!/usr/bin/env bash
# IZIN_SAHAMAP — BÜTÜNSEL Saha sunucu yetkilendirmesi: merkezi SAHA_DEPT_MAP + requireSahaAccess
#   içinde tek uygulama noktası. TÜM eşlenen Saha uçları aynı anda departments[] denetler.
#   requireBiDept felsefesi Saha'nın tamamına. Yalniz server. Tek build.
#   NOT: bu, 3-uçlu 'sahadept' yamasinin YERINE gecer (onu deploy etmeyin; edilmisse zararsiz coexist).
# KULLANIM (deriveapp klasoru):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_izin_sahamap.sh patch_izin_sahamap_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_izin_sahamap.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_izin_sahamap_server.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "async function requireSahaAccess(req, allowedRoles = null) {" "$SRV" || { echo "HATA: requireSahaAccess imzasi beklenenden farkli"; exit 1; }
grep -q "requireBiDept" "$SRV" || { echo "HATA: requireBiDept yok (taban beklenmedik)"; exit 1; }

if grep -q IZIN_SAHAMAP_V1 "$SRV"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_izin_sahamap_server.py "$SRV" || { echo "PATCH HATASI; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/sahamap_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/sahamap_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] SAHA_DEPT_MAP: "; docker exec "$CID" grep -c "const SAHA_DEPT_MAP" /app/server.mjs || true
echo -n "[dogrula] uygulama noktasi: "; docker exec "$CID" grep -c "_enforceSahaDept(req, _sess)" /app/server.mjs || true
echo -n "[dogrula] eslenen uc sayisi: "; docker exec "$CID" grep -oE '"/api/saha/[^"]+": \[' /app/server.mjs | wc -l || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Saha izin matrisi artik BASTAN SONA sunucuda gecerli: yetkisiz sekme = 403. Bos departman = role fallback (kimse kaybetmez)."
