#!/usr/bin/env bash
# BRAIN_CACHE_V1 — CEO Assistant sistem promptu + tool tanimlari prompt-cache.
#   _brainSysCache() promptu "SISTEM HARITASI" sinirindan boler; buyuk STATIK blogu
#   cache_control:ephemeral ile isaretler. Isaret yoksa duz string doner (davranis korunur).
#   NOT: Tasarruf ancak Anthropic kredisi dolunca gerceklesir. Kod-tarafi tek is bu.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_brain_cache.sh patch_brain_cache.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_brain_cache.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_brain_cache.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q '_handleBrainChat' "$F" || { echo "HATA: $F CEO chat akisi yok — DUR."; exit 1; }
grep -q 'system: systemPrompt,' "$F" || { echo "HATA: $F beklenen system satiri yok — DUR."; exit 1; }
if grep -q 'BRAIN_CACHE_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_brain_cache.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/braincache_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/braincache_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/server.mjs (BRAIN_CACHE_V1, 2 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c BRAIN_CACHE_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Kredi dolunca: CEO Assistant'a birkac soru sor -> Console 'Prompt caching' karti 'tokens reused' gostermeli."
