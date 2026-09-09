#!/usr/bin/env bash
# MUSTERI_KART_WARM_V1 — mobil müşteri kartı sıcak palet + firma adı kesik fix (yalnız saha.js). Rollback'li.
# KULLANIM: scp -i $KEY deploy_musteri_kart_warm.sh patch_musteri_kart_warm.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_kart_warm.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] && [ -f patch_musteri_kart_warm.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "MUSTERI_KART_OLAYLAR_V1" "$MOB" || { echo "HATA: önce MUSTERI_KART_OLAYLAR_V1 olmalı"; exit 1; }
TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
python3 patch_musteri_kart_warm.py "$MOB" || { cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
node --check "$MOB" || { echo "HATA node"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/warm_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/warm_build.log; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] WARM_V1: "; docker exec "$CID" grep -c MUSTERI_KART_WARM_V1 /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_KART_WARM_V1','Mobil musteri karti sicak DS palete cekildi (scoped .modal-kutu.mkc override: baslik/ayrac/buton) + firma adi kesik fix (safe-area-inset-top) + finansal inline hucre krem + bar yesil. Yalniz bu karti etkiler.','Canli kart mock kadar guzel degildi: ust sicak, govde slate + firma adi kesikti. Kozmetik birlestirme pass.','{"marker":"MUSTERI_KART_WARM_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_WARM_V1');
SELECT count(*) warm FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_WARM_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_KART_WARM_V1 CANLI — kart sıcak palet + firma adı tam. Hard-refresh (bu sefer client değişti → cache atla)."
