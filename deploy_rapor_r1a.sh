#!/usr/bin/env bash
# RAPOR_R1A — GUVEN duzeltmeleri (server, dogruluk buglari): Saha ROI kapsam 12-ay + ort_ciro 12-ay; Rotam plan-tespiti
#   COALESCE(ziyaret_tarihi,planlanan_tarih) (Planla/Ilet artik Rotam'a duser); Rotam yonetici veri-kapsami (_sahaScopeSql);
#   Ciro yonetici mukerrer toplam -> distinct gercek toplam alani. Yalniz server_container.mjs. DB degisikligi YOK. Rollback'li.
#   KULLANIM:
#     scp -i $KEY deploy_rapor_r1a.sh patch_rapor_r1a_server.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_r1a.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_rapor_r1a_server.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "_sahaScopeSql" "$SRV" || { echo "HATA: _sahaScopeSql yok (FAZ3A)"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_rapor_r1a_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
cp -a "$SRV" _r1a_esm.mjs && node --check _r1a_esm.mjs || { echo "HATA node ESM"; rm -f _r1a_esm.mjs; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
rm -f _r1a_esm.mjs; echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/r1a_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/r1a_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] RAPOR_R1A (>=6): ";        docker exec "$CID" grep -c RAPOR_R1A /app/server.mjs || true
echo -n "[srv] ROI vc>0 kapsam (1): ";    docker exec "$CID" grep -c 'x.vc > 0).length' /app/server.mjs || true
echo -n "[srv] Rotam COALESCE plan (2): ";docker exec "$CID" grep -c 'COALESCE(ziyaret_tarihi, planlanan_tarih)=CURRENT_DATE' /app/server.mjs || true
echo -n "[srv] Rotam scope (1): ";        docker exec "$CID" grep -c '_cuScope = _sahaScopeSql' /app/server.mjs || true
echo -n "[srv] Ciro distinct toplam (2): ";docker exec "$CID" grep -c 'toplam_etki_ciro' /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'RAPOR_R1A',
 'Rapor guven duzeltmeleri (server): (1) Saha ROI kapsam sayimi ever(tum-zaman) -> vc>0 (son 12 ay); grup/ihmal ort_ciro h1(6ay) -> h1+h2 (12 ay, "yillik cirosu" durust). (2) Rotam plan-tespiti ziyaret_tarihi -> COALESCE(ziyaret_tarihi,planlanan_tarih) 3 noktada (Kapsam Planla/Ilet PLANLANDI satirini planlanan_tarih ile ekliyordu, ziyaret_tarihi NULL -> Rotam gormuyordu; "Rotam a duser" sozu artik dogru). (3) Rotam yonetici panosu cu sorgusuna _sahaScopeSql (bolge/bolum yoneticisi tenant-genelini gormesin; opt-in, tumu/admin -> filtre yok). (4) Ciro yonetici "Toplam etki ciro": rep satirlarini toplamak ortak musteriyi mukerrer sayip gercegi asiyordu -> distinct-musteri gercek toplam alani (toplam_etki_ciro/toplam_musteri) eklendi (client R1B tuketecek).',
 'derive-rapor-denetim.md Faz R1 (guven). 3 paralel denetim ajaninin bulgulari: 5 HIGH dogruluk/guven bug''i. Dunya-standardi = once DOGRU.',
 '{"marker":"RAPOR_R1A","tur":"duzeltme","yuzey":"server","fix":["roi_kapsam_12ay","roi_ortciro_12ay","rotam_plan_coalesce","rotam_yonetici_scope","ciro_distinct_toplam"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='RAPOR_R1A');
SELECT count(*) r1a FROM bi_insa_gunlugu WHERE adim='RAPOR_R1A';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] RAPOR_R1A CANLI — Saha ROI kapsam/ciro dürüst; Rotam Planla/İlet çalışır + yönetici kapsamı; Ciro gerçek toplam hazır (client R1B). (hard-refresh)"
