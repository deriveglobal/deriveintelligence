#!/usr/bin/env bash
# SEKME_CAP_FIX_V1 — enforcement acigi kapatma: client flip anahtari _rHasNew -> _rd.length (deny-by-default).
#   Bir kisiyi (Kisiler) [ozet]'e indirince artik rol-fallback'a DUSMEZ, yalniz isaretli sekmeleri gorur.
#   Yalniz 2 kabuk (saha.js + saha_desktop.js); server zaten strict (degismez), DB/backfill YOK. Rollback'li tek build.
#   On kosul: SEKME_CAP canli. KULLANIM:
#     scp -i $KEY deploy_sekme_fix.sh patch_sekme_fix_saha.py patch_sekme_fix_sahad.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_sekme_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
SH=shells/saha.js; SD=shells/saha_desktop.js
for f in "$SH" "$SD" patch_sekme_fix_saha.py patch_sekme_fix_sahad.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q SEKME_CAP_MOB_V1 "$SH" || { echo "HATA: SEKME_CAP_MOB_V1 yok (once deploy_sekme_cap.sh)"; exit 1; }
TS=$(date +%s); cp -a "$SH" "$SH.bak.$TS"; cp -a "$SD" "$SD.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo ROLLBACK; cp -a "$SH.bak.$TS" "$SH"; cp -a "$SD.bak.$TS" "$SD"; }
python3 patch_sekme_fix_saha.py  "$SH" || { rollback; exit 1; }
python3 patch_sekme_fix_sahad.py "$SD" || { rollback; exit 1; }
node --check "$SH" && node --check "$SD" || { echo "HATA node"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/sekmefix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/sekmefix_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[saha] SEKME_CAP_FIX_V1 (1): ";  docker exec "$CID" grep -c SEKME_CAP_FIX_V1 /app/shells/saha.js || true
echo -n "[sahad] SEKME_CAP_FIX_V1 (1): "; docker exec "$CID" grep -c SEKME_CAP_FIX_V1 /app/shells/saha_desktop.js || true
echo -n "[saha] _rd.length gate (1): ";   docker exec "$CID" grep -c '_rd.length ? _rd.includes(id)' /app/shells/saha.js || true
echo -n "[saha] eski _rHasNew?_rd kalıntı (0): "; docker exec "$CID" grep -c '_rHasNew ? _rd.includes' /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SEKME_CAP_FIX_V1',
 'Client sekme kapisi enforcement acigi kapatildi: _rTabOk flip anahtari _rHasNew (ciro/risk/rotam/kapsam var mi) -> _rd.length (dolu departments). Bir kisi Kisiler''den [ozet]''e indirilince artik rol-fallback''a DUSMUYOR; yalniz isaretli sekmeleri goruyor (deny-by-default). Bos departments -> fallback korundu (regresyonsuz; backfill sonrasi dolu-dept herkeste tab capleri var, gorunum ayni). saha.js + saha_desktop.js. Server zaten strict''ti (degismedi).',
 'Fatih testi: Satis sablonunda/kiside yalniz ozet birakip Ali Kemal hesabina bakinca digerleri hala goruniyordu. Kok: SEKME_CAP''te regresyon korkusuyla yeni sekmeler rol-fallback''ta daima-acikti; kisi tab-cap''siz kalinca fallback onlari geri gosteriyordu.',
 '{"marker":"SEKME_CAP_FIX_V1","tur":"yetki","yuzeyler":["saha.js","saha_desktop.js"],"degisiklik":"flip _rHasNew->_rd.length","not":"per-kisi kisitlama Kisiler(replace) ile; Bolumler uygula additive-grant"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SEKME_CAP_FIX_V1');
SELECT count(*) fix FROM bi_insa_gunlugu WHERE adim='SEKME_CAP_FIX_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] SEKME_CAP_FIX_V1 CANLI — Kişiler'de bir kişiyi kırpınca artık gerçekten gizlenir. (hard-refresh + kişi yeniden giriş)"
