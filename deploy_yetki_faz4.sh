#!/usr/bin/env bash
# YETKI_FAZ4 — Bölümler OTORİTER + Kişiler istisna (üç ekran tek zincir). Yalnız server_container.mjs.
#   Yetki = (bölüm şablonları ∪ personal_grant) − personal_deny. apply/üyelik/Kişiler bu formülden geçer.
#   Migrasyon GÜVENLİ: personal_grant/deny=[] init eder, departments'a DOKUNMAZ → deploy anında CANLI DEĞİŞİKLİK YOK.
#   Değişim ancak sen bir bölüme "uygula" deyince (o bölüm üyeleri şablona iner) ya da Kişiler'den kaydedince olur.
#   KULLANIM:
#     scp -i $KEY deploy_yetki_faz4.sh patch_yetki_faz4_server.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz4.sh'
set -euo pipefail
cd /opt/krb-assessment
TID='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_yetki_faz4_server.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q YETKI_FAZ2A "$SRV" || { echo "HATA: YETKI_FAZ2A yok (önce Faz2a)"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_yetki_faz4_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
cp -a "$SRV" _faz4_esm.mjs && node --check _faz4_esm.mjs || { echo "HATA node ESM"; rm -f _faz4_esm.mjs; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
rm -f _faz4_esm.mjs; echo "[ok] syntax"
# ── migrasyon (GÜVENLİ: personal alanlarını init et, departments'a dokunma; idempotent) ──
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<SQL || { echo "HATA migrasyon"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
\set ON_ERROR_STOP on
UPDATE tenant_user_modules
SET permissions_json = jsonb_set(jsonb_set(COALESCE(permissions_json,'{}'::jsonb),'{personal_grant}','[]'::jsonb),'{personal_deny}','[]'::jsonb)
WHERE tenant_id::text='${TID}' AND module_id='saha'
  AND NOT (COALESCE(permissions_json,'{}'::jsonb) ? 'personal_grant');
SELECT count(*) AS personal_init FROM tenant_user_modules WHERE tenant_id::text='${TID}' AND module_id='saha' AND permissions_json ? 'personal_grant';
SQL
echo "[db] migrasyon ok (departments dokunulmadı → canlı değişiklik yok)"
docker build -t krb-assessment:secure . >/tmp/faz4_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/faz4_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] YETKI_FAZ4 (4): ";           docker exec "$CID" grep -c YETKI_FAZ4 /app/server.mjs || true
echo -n "[srv] _recomputeSahaCaps (>=3): "; docker exec "$CID" grep -c _recomputeSahaCaps /app/server.mjs || true
echo -n "[srv] apply additive kalıntı (0): ";docker exec "$CID" grep -c 'UNION SELECT jsonb_array_elements_text(\$2::jsonb)' /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ4',
 'Bolumler OTORITER + Kisiler istisna (uc ekran tek zincir). Kisi saha yetkisi = (uye oldugu bolum sablonlari BIRLESIMI union personal_grant) eksi personal_deny. server: _recomputeSahaCaps + _sahaDeptUnion; apply (Bolumler uygula) additive-push YERINE scope yaz + recompute (sablon=yasa, kaldirilan duser); uyelik ekle/cikar -> recompute; Kisiler PATCH -> gonderilen departments(=isaretli) vs bolum-birlesimi farkindan personal_grant/deny turet+sakla (istisna sonraki apply da EZILMEZ). Tuketiciler (permissions_json.departments) degismez. Migrasyon GUVENLI: personal alanlari []=init, departments dokunulmadi -> deploy aninda canli degisiklik yok; degisim ancak apply/Kisiler ile.',
 'Fatih: Roller/Kisiler/Bolumler birbiriyle konusmuyordu (Bolumler additive=kaldirmiyor, Kisiler replace). Karar B: Bolumler otoriter. Standart SaaS: grup yasasi + kisisel istisna + rol referans.',
 '{"marker":"YETKI_FAZ4","tur":"yetki","yuzey":"server","formul":"(dept_union U grant) - deny","hook":["apply","uyelik","kisiler_patch"],"migrasyon":"personal=[] init, departments dokunulmadi"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ4');
SELECT count(*) faz4 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ4';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ4 CANLI — Bölümler artık YASA. Şablona 'uygula' → üyeler şablona iner; Kişiler = kişisel istisna (apply ezmez)."
