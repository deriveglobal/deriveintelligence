#!/usr/bin/env bash
# PORTFOY_INTRO_V1 — Portföy sekmesine kanonik "ne işe yarar?" intro kartı (masaüstü + mobil).
#   Ev kuralı: her sekme, şirketi tanımayan birinin bile anlayacağı açıklama taşır (Ciro/Kapsam gibi).
#   Yalnız UI (saha_desktop.js + saha.js); server DEĞİŞMEZ. Rollback'li, tek build.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_portfoy_intro.sh patch_portfoy_intro_desktop.py patch_portfoy_intro_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_portfoy_intro.sh'
set -euo pipefail
cd /opt/krb-assessment
DK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$DK" "$MOB"; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
for p in patch_portfoy_intro_desktop.py patch_portfoy_intro_mobile.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q "PORTFOY_DK_V1" "$DK"   || { echo "HATA: önce PORTFOY_DK_V1 canlı olmalı"; exit 1; }
grep -q "PORTFOY_MOB_V1" "$MOB" || { echo "HATA: önce PORTFOY_MOB_V1 canlı olmalı"; exit 1; }
TS=$(date +%s)
cp -a "$DK" "$DK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$DK.bak.$TS" "$DK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_portfoy_intro_desktop.py "$DK"  || { rollback; exit 1; }
python3 patch_portfoy_intro_mobile.py  "$MOB" || { rollback; exit 1; }
node --check "$DK"  || { echo "HATA desktop node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$DK" /tmp/_dk.mjs; node --check /tmp/_dk.mjs || { echo "HATA esm desktop"; rollback; exit 1; }
cp "$MOB" /tmp/_mob.mjs; node --check /tmp/_mob.mjs || { echo "HATA esm mobil"; rollback; exit 1; }
echo "[ok] syntax (desktop + mobil)"
docker build -t krb-assessment:secure . >/tmp/pfi_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/pfi_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] desktop PORTFOY_INTRO_DK_V1: "; docker exec "$CID" grep -c PORTFOY_INTRO_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil PORTFOY_INTRO_MOB_V1: ";   docker exec "$CID" grep -c PORTFOY_INTRO_MOB_V1 /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOY_INTRO_V1',
 'Portfoy sekmesine kanonik "ne ise yarar?" intro karti (masaustu + mobil, ust). Amac paragrafi + tanim satirlari (Ritim/Durum, aktif/soguyor/pasif, risk cirosu, alim_yok, tek-kaynak). Dipteki HOW + kisisel CTX kaldirildi (intro kapsiyor).',
 'Uygulama kurali (Fatih): her sekme, sirketi tanimayan birinin bile "bu sayfa ne ise yarar" diye anlayabilecegi bir aciklama karti tasir — Ciro/Kapsam gibi. Portfoy''de ust intro eksikti.',
 '{"marker":"PORTFOY_INTRO_V1","surface":["saha_desktop","saha.js"],"kural":"her-sekme-ne-ise-yarar"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOY_INTRO_V1');
SELECT 'insa_intro' k, count(*) n FROM bi_insa_gunlugu WHERE adim='PORTFOY_INTRO_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] PORTFOY_INTRO_V1 CANLI — Saha › 🩺 Portföy üstünde 'ne işe yarar?' kartı. Hard-refresh."
