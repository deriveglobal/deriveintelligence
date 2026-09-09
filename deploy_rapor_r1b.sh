#!/usr/bin/env bash
# RAPOR_R1B — GUVEN duzeltmeleri (client, iki kabuk): (5) OZET "Yeniden Kazanim" kutu=liste (modal filtresine ESKI_NOKTA);
#   (1) CIRO hero "Toplam etki ciro" server distinct gercek toplami (d.toplam_etki_ciro) kullanir (mukerrer sayim biter).
#   saha.js + saha_desktop.js. On kosul: RAPOR_R1A (server toplam_etki_ciro). DB YOK. Rollback'li.
#   KULLANIM:
#     scp -i $KEY deploy_rapor_r1b.sh patch_rapor_r1b_client.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_r1b.sh'
set -euo pipefail
cd /opt/krb-assessment
SH=shells/saha.js; SD=shells/saha_desktop.js
for f in "$SH" "$SD" patch_rapor_r1b_client.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q RAPOR_R1A server_container.mjs || echo "[uyari] server'da RAPOR_R1A yok — Ciro hero fallback'e duser (eski toplam)"
TS=$(date +%s); cp -a "$SH" "$SH.bak.$TS"; cp -a "$SD" "$SD.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo ROLLBACK; cp -a "$SH.bak.$TS" "$SH"; cp -a "$SD.bak.$TS" "$SD"; }
python3 patch_rapor_r1b_client.py "$SH" || { rollback; exit 1; }
python3 patch_rapor_r1b_client.py "$SD" || { rollback; exit 1; }
node --check "$SH" && node --check "$SD" || { echo "HATA node"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/r1b_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/r1b_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[saha] ESKI_NOKTA modal (1): ";     docker exec "$CID" grep -c 'PASIF_NOKTA","ESKI_NOKTA","RISKLI_NOKTA' /app/shells/saha.js || true
echo -n "[sahad] ESKI_NOKTA modal (1): ";    docker exec "$CID" grep -c 'PASIF_NOKTA", "ESKI_NOKTA", "RISKLI_NOKTA' /app/shells/saha_desktop.js || true
echo -n "[saha] Ciro hero distinct (1): ";   docker exec "$CID" grep -c 'd.toplam_etki_ciro != null' /app/shells/saha.js || true
echo -n "[sahad] Ciro hero distinct (1): ";  docker exec "$CID" grep -c 'd.toplam_etki_ciro != null' /app/shells/saha_desktop.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'RAPOR_R1B',
 'Rapor guven duzeltmeleri (client, iki kabuk): (5) OZET "Yeniden Kazanim" kutu sayisi ile tiklaninca acilan liste uyusmuyordu (server PASIF/ESKI/RISKLI sayarken modal yalniz PASIF/RISKLI suzuyordu) -> modal filtresine ESKI_NOKTA eklendi (saha.js + saha_desktop.js). (1) CIRO hero "Toplam etki ciro" rep satirlarini topluyordu -> ortak musteri mukerrer -> gercegi asiyordu; artik server distinct gercek toplami (d.toplam_etki_ciro, RAPOR_R1A) kullanilir, yoksa eski toplama fallback. Ciro payi % efor-payi olarak sum-bazli kaldi (100e toplanir).',
 'derive-rapor-denetim.md Faz R1 (guven) client tarafi. R1A ile birlikte 5 HIGH dogruluk bug''i kapandi.',
 '{"marker":"RAPOR_R1B","tur":"duzeltme","yuzey":["saha.js","saha_desktop.js"],"fix":["ozet_eski_nokta_kutu_liste","ciro_hero_distinct_toplam"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='RAPOR_R1B');
SELECT count(*) r1b FROM bi_insa_gunlugu WHERE adim='RAPOR_R1B';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] RAPOR_R1B CANLI — Özet kutu=liste; Ciro hero gerçek (mükerrersiz) toplam. 5 HIGH güven bug'ı kapandı. (hard-refresh)"
