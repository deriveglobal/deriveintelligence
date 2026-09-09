#!/usr/bin/env bash
# YETKI_FAZ3C — veri kapsamini agregat raporlara genislet (Kapsam/Portfoy/Saha ROI/kapsam-export).
#   Yonetici dalina _sahaScopeSql: scope kendi/bolge/bolum -> filtreli; tumu/ayarsiz/admin -> filtresiz (regresyonsuz).
#   Yalniz server_container.mjs. DB degisikligi YOK. On kosul: YETKI_FAZ3A (_sahaScopeSql). Rollback'li.
#   KULLANIM:
#     scp -i $KEY deploy_yetki_faz3c.sh patch_yetki_faz3c_server.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz3c.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_yetki_faz3c_server.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "_sahaScopeSql" "$SRV" || { echo "HATA: _sahaScopeSql yok (once YETKI_FAZ3A)"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_yetki_faz3c_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
cp -a "$SRV" _faz3c_esm.mjs && node --check _faz3c_esm.mjs || { echo "HATA node ESM"; rm -f _faz3c_esm.mjs; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
rm -f _faz3c_esm.mjs; echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz3c_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/faz3c_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] YETKI_FAZ3C else-scope (4): "; docker exec "$CID" grep -c 'YETKI_FAZ3C' /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ3C',
 'Veri kapsami agregat raporlara genisletildi: /api/saha/rapor/kapsam + /portfoy + /ziyaret-etki + /kapsam-export yonetici dalina _sahaScopeSql (alias m=saha_musteri). rep -> m.sorumlu_rep=self (degismedi); yonetici -> scope kendi/bolge/bolum ise filtreli, tumu/ayarsiz/admin ise filtresiz. OPT-IN, regresyonsuz. 4 uc tek desen (replace_all).',
 'derive-yetki-toparlama.md Faz 3c. Faz 3a/3b tekil+liste kapsamini zorluyordu; agregat ozet raporlar hala tum-tenant gosteriyordu -> scoped yonetici kendi bolgesi/bolumu ozetini gormeli.',
 '{"marker":"YETKI_FAZ3C","tur":"yetki","yuzey":"server","uclar":["rapor/kapsam","rapor/portfoy","rapor/ziyaret-etki","rapor/kapsam-export"],"kaynak":"_sahaScopeSql (FAZ3A)","opt_in":true}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ3C');
SELECT count(*) faz3c FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ3C';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ3C CANLI — scoped yönetici artık Kapsam/Portföy/Saha ROI'de yalnız kendi bölge/bölüm özetini görür."
