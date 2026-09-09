#!/usr/bin/env bash
# BAYILIK_SCOPE_FIX_V1 — teklif panelinde maliyet/marj'in TAMAMEN bos cikmasinin kok nedeni:
#   _bayilikMi beyin blogunda kaliyor, saha kapsami goremiyor -> ReferenceError -> yutulur.
#   Bu yama saha-kapsam kopyalari ekler; TUM tekliflerde maliyet/marj geri gelir.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_bayilik_scope.sh patch_bayilik_scope.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_bayilik_scope.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_bayilik_scope.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q '_bayilikMi(pool, session.tenantId' "$F" || { echo "HATA: cagri yeri yok — DUR."; exit 1; }
if grep -q 'BAYILIK_SCOPE_FIX_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_bayilik_scope.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/bayilikscope_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/bayilikscope_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker BAYILIK_SCOPE_FIX_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c BAYILIK_SCOPE_FIX_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Mobil/masaustu -> onay bekleyen teklifi ac -> her kalemde artik MALIYET+MARJ gorunmeli (son alis / brut maliyet)."
