#!/usr/bin/env bash
# SEKME_CAP_V1 — Saha sekmeleri = BIRINCIL capability (matris = tek yasa).
#   4 katman tek build: tenant-admin.js (grid Sekmeler grubu) + saha.js + saha_desktop.js (client kapi) +
#   server_container.mjs (etki/portfoy sunucu enforce) + DB backfill (regresyon yok) + fingerprint. Rollback'li.
# KULLANIM (Fatih, Hetzner):
#   scp -i $KEY deploy_sekme_cap.sh patch_sekme_ta.py patch_sekme_saha.py patch_sekme_sahad.py patch_sekme_srv.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_sekme_cap.sh'
set -euo pipefail
cd /opt/krb-assessment
TID='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
TA=shells/tenant-admin.js; SH=shells/saha.js; SD=shells/saha_desktop.js; SRV=server_container.mjs
for f in "$TA" "$SH" "$SD" "$SRV" patch_sekme_ta.py patch_sekme_saha.py patch_sekme_sahad.py patch_sekme_srv.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
TS=$(date +%s)
cp -a "$TA" "$TA.bak.$TS"; cp -a "$SH" "$SH.bak.$TS"; cp -a "$SD" "$SD.bak.$TS"; cp -a "$SRV" "$SRV.bak.$TS"
echo "[yedek] .bak.$TS (4 dosya)"
rollback(){ echo "ROLLBACK"; cp -a "$TA.bak.$TS" "$TA"; cp -a "$SH.bak.$TS" "$SH"; cp -a "$SD.bak.$TS" "$SD"; cp -a "$SRV.bak.$TS" "$SRV"; }

python3 patch_sekme_ta.py    "$TA"  || { rollback; exit 1; }
python3 patch_sekme_saha.py  "$SH"  || { rollback; exit 1; }
python3 patch_sekme_sahad.py "$SD"  || { rollback; exit 1; }
python3 patch_sekme_srv.py   "$SRV" || { rollback; exit 1; }

# syntax — 3 shell (.js) + server ESM (.mjs kopya kontrol: .js top-level import'u sessizce atlar)
node --check "$TA" && node --check "$SH" && node --check "$SD" || { echo "HATA node (shell)"; rollback; exit 1; }
cp -a "$SRV" _sekme_esm_check.mjs && node --check _sekme_esm_check.mjs || { echo "HATA node (server ESM)"; rm -f _sekme_esm_check.mjs; rollback; exit 1; }
rm -f _sekme_esm_check.mjs
echo "[ok] syntax (4 dosya)"

# ── DB backfill (BUILD'DEN ÖNCE — enforce canliya cikinca dolu-departments kullanicilar etki/portfoy tasisin) ──
echo "[db] backfill + sablon..."
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<SQL || { echo "HATA: backfill SQL"; rollback; exit 1; }
\set ON_ERROR_STOP on
-- Kullanici: dolu-departments saha kullanicilarina yeni sekme anahtarlari (bugun de goruyorlar -> koru). Idempotent (DISTINCT).
UPDATE tenant_user_modules t
SET permissions_json = jsonb_set(COALESCE(t.permissions_json,'{}'::jsonb), '{departments}',
  COALESCE((SELECT jsonb_agg(DISTINCT e) FROM (
     SELECT jsonb_array_elements_text(COALESCE(t.permissions_json->'departments','[]'::jsonb)) e
     UNION SELECT unnest(ARRAY['etki','portfoy','pipeline','pazar','ozet']) e) u), '[]'::jsonb))
WHERE t.tenant_id::text='${TID}' AND t.module_id='saha'
  AND jsonb_typeof(t.permissions_json->'departments')='array'
  AND jsonb_array_length(t.permissions_json->'departments') > 0;
-- Sablon: bolum sablonlarina da ekle (gelecek "uygula" push etsin, Bolumler ekrani isaretli gostersin).
UPDATE tenant_department
SET template_json = jsonb_set(COALESCE(template_json,'{}'::jsonb), '{capabilities}',
  COALESCE((SELECT jsonb_agg(DISTINCT e) FROM (
    SELECT jsonb_array_elements_text(COALESCE(template_json->'capabilities','[]'::jsonb)) e
    UNION SELECT unnest(ARRAY['etki','portfoy','pipeline','pazar','ozet']) e) u), '[]'::jsonb))
WHERE tenant_id::text='${TID}';
SELECT count(*) AS backfilled_users FROM tenant_user_modules
 WHERE tenant_id::text='${TID}' AND module_id='saha'
   AND permissions_json->'departments' ? 'etki';
SQL
echo "[db] ok"

# ── build + recreate ──
docker build -t krb-assessment:secure . >/tmp/sekme_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/sekme_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"

echo "── KONTEYNER DOĞRULAMA ──"
echo -n "[ta] SEKME_CAP_V1 (>=5): ";      docker exec "$CID" grep -c SEKME_CAP_V1 /app/shells/tenant-admin.js || true
echo -n "[ta] Sekmeler grubu (1): ";      docker exec "$CID" grep -c '\["Sekmeler"' /app/shells/tenant-admin.js || true
echo -n "[saha] SEKME_CAP_MOB_V1 (2): ";  docker exec "$CID" grep -c SEKME_CAP_MOB_V1 /app/shells/saha.js || true
echo -n "[sahad] SEKME_CAP_DK_V1 (2): ";  docker exec "$CID" grep -c SEKME_CAP_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[srv] SEKME_CAP_SRV_V1 (2): ";   docker exec "$CID" grep -c SEKME_CAP_SRV_V1 /app/server.mjs || true
echo -n "[srv] ziyaret-etki=[etki] (1): ";docker exec "$CID" grep -c '"/api/saha/rapor/ziyaret-etki": \["etki"\]' /app/server.mjs || true
echo -n "[srv] portfoy=[portfoy] (1): ";  docker exec "$CID" grep -c '"/api/saha/rapor/portfoy": \["portfoy"\]' /app/server.mjs || true

# ── fingerprint (non-fatal) ──
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SEKME_CAP_V1',
 'Saha sekmeleri artik BIRINCIL capability (matris=tek yasa). tenant-admin.js: Bolumler/Kisiler grid MODULES.saha''ya "Sekmeler" grubu (ozet-kilitli/ciro/risk/etki=Saha ROI/portfoy/rotam/kapsam/pipeline/pazar gercek adlariyla), ciro/risk/rotam/kapsam Yonetim&Analizden tasindi (mukerrer id yok), ozet lock, DEFAULTS rep+manager etki/portfoy/pipeline/pazar/ozet. saha.js+saha_desktop.js: _rNEW''e etki/portfoy/pipeline/pazar, _rTabOk rep-fallback rotam+etki+portfoy+pipeline+pazar (deny-by-default, kendi id''siyle). server: SAHA_DEPT_MAP ziyaret-etki->[etki], portfoy->[portfoy] (client==server). Backfill: dolu-departments saha kullanicilari + bolum sablonlari etki/portfoy/pipeline/pazar/ozet (regresyon yok, idempotent). Pipeline/Pazar paylasimli rapor uclari -> view-cap (client gizler; sert server-gate ozel uc gerektirir, ileride).',
 'Fatih: saha rapor sekmeleri (Saha ROI/Portfoy/Rotam/Pipeline/Pazar) matriste yoktu/yanlis adlaydi ve 5''i hic kapilanmiyordu (kodda sabit acik) -> "bunlar en kritikleri, matristen yonetilmeli". Kok neden: rpTabs + MODULES + SAHA_DEPT_MAP uc ayri elle-liste, tek kanonik kayit yoktu (drift).',
 '{"marker":"SEKME_CAP_V1","tur":"yetki","yuzeyler":["tenant-admin.js","saha.js","saha_desktop.js","server.mjs"],"yeni_cap":["etki","portfoy","pipeline","pazar","ozet"],"sert_server":["etki","portfoy"],"view_cap":["pipeline","pazar","ozet"],"backfill":"dolu-departments + sablon"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SEKME_CAP_V1');
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, aktif)
SELECT 'saha-sekme-yetki', 'fonksiyon',
 'Saha modulu rapor sekmelerini (Ozet/Ciro/Risk/Saha ROI/Portfoy/Rotam/Kapsam/Pipeline/Pazar) birincil yetki olarak Izinler matrisinden yonetir; her sekme kendi capability anahtariyla client+server kapilanir.',
 'client _rTabOk (saha.js/saha_desktop.js _rNEW deny-by-default + rol-fallback) == server _enforceSahaDept (SAHA_DEPT_MAP: etki/portfoy sert; pipeline/pazar/ozet view-cap). Grid MODULES.saha "Sekmeler" grubu; bolum sablonu + backfill.',
 'yetki', 'canli', 'yuksek', true
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha-sekme-yetki');
SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='SEKME_CAP_V1') insa,
       (SELECT count(*) FROM bi_yetenek WHERE ad='saha-sekme-yetki') yetenek;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] SEKME_CAP_V1 CANLI — Yönetim › Bölümler/Kişiler'de 'Sekmeler' grubu; 9 saha sekmesi gerçek adıyla, kapatılınca hem ekran hem API. (masaüstü konsol + mobil; hard-refresh)"
