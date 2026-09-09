#!/usr/bin/env bash
# YETKI_FAZ5 (5a) — Etkin-yetki DENETCI: server GET /api/tenant/users/:id/yetki-kaynak + konsol "Denetim > Yetki Denetimi".
#   Bir kisiye bak -> her saha yetkisi NEREDEN (bolum / kisisel-ekleme / kisisel-cikarma / admin). Salt-oku, DB degisikligi YOK.
#   2 dosya tek build, rollback'li. KULLANIM:
#     scp -i $KEY deploy_yetki_faz5.sh patch_yetki_faz5_server.py patch_yetki_faz5_client.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz5.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; TA=shells/tenant-admin.js
for f in "$SRV" "$TA" patch_yetki_faz5_server.py patch_yetki_faz5_client.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q YETKI_FAZ4 "$SRV" || echo "[uyari] server'da YETKI_FAZ4 yok (personal_grant/deny denetci icin gerekir)"
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo ROLLBACK; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$TA.bak.$TS" "$TA"; }
python3 patch_yetki_faz5_server.py "$SRV" || { rollback; exit 1; }
python3 patch_yetki_faz5_client.py "$TA" || { rollback; exit 1; }
node --check "$TA" || { echo "HATA node (konsol)"; rollback; exit 1; }
cp -a "$SRV" _faz5_esm.mjs && node --check _faz5_esm.mjs || { echo "HATA node (server ESM)"; rm -f _faz5_esm.mjs; rollback; exit 1; }
rm -f _faz5_esm.mjs; echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz5_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/faz5_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] yetki-kaynak ucu (1): ";     docker exec "$CID" grep -c 'yetki-kaynak' /app/server.mjs || true
echo -n "[ta] renderYetkiDenetim (1): ";    docker exec "$CID" grep -c 'async function renderYetkiDenetim' /app/shells/tenant-admin.js || true
echo -n "[ta] nav yetki-denetim (2): ";     docker exec "$CID" grep -c 'yetki-denetim' /app/shells/tenant-admin.js || true
echo -n "[ta] yd-* stil (1): ";             docker exec "$CID" grep -c '.yd-cap{' /app/shells/tenant-admin.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ5',
 'Etkin-yetki DENETCI (5a): server GET /api/tenant/users/:id/yetki-kaynak (module_role, departments-etkin, personal_grant, personal_deny, scope, bolumler[ad,ikon,caps]) + konsol Denetim>Yetki Denetimi gorunumu (kisi sec -> her saha yetkisi nereden: bolum/kisisel-ekleme/kisisel-cikarma/admin; renk-kodlu, bolum adi tooltip). Salt-oku. Stiller taStyles() yd-* (gomme yok). admin uyarisi (departments okumaz).',
 'derive-yetki-toparlama.md Faz 5. Fatih Ali icin DB sorgusuyla debug etti (neden hepsini goruyor) -> self-servis denetci: bir kisinin etkin yetkisinin kaynagini tek ekranda goster.',
 '{"marker":"YETKI_FAZ5","tur":"yetki","yuzey":["server","tenant-admin.js"],"uc":"/api/tenant/users/:id/yetki-kaynak","gorunum":"Denetim>Yetki Denetimi","salt_oku":true}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ5');
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, aktif)
SELECT 'tenant-yetki-denetci', 'uc',
 'Bir kisinin saha yetkisinin kaynagini (bolum sablonu / kisisel-ekleme / kisisel-cikarma / admin) tek ekranda gosterir; yonetici "neden bunu goruyor" sorusunu self-servis yanitlar.',
 'GET /api/tenant/users/:id/yetki-kaynak (requireTenantAdmin) -> tenant_user_modules.permissions_json (departments/personal_grant/personal_deny/scope) + tenant_department uyelik+template. Konsol Denetim>Yetki Denetimi provenance hesaplar.',
 'yetki', 'canli', 'yuksek', true
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant-yetki-denetci');
SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ5') insa, (SELECT count(*) FROM bi_yetenek WHERE ad='tenant-yetki-denetci') yetenek;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ5 (5a) CANLI — Yönetim > Denetim > Yetki Denetimi. Bir kişi seç, her yetkinin nereden geldiğini gör. (hard-refresh)"
