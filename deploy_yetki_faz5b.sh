#!/usr/bin/env bash
# YETKI_FAZ5B — yetki degisiklik GUNLUGU (denetim) + eski Izinler grid'ini nav'dan kaldir.
#   DDL tenant_yetki_log + server (_yetkiLog + 3 yazma-yolu log + GET /api/tenant/yetki-log) + konsol (Yetki Gunlugu view).
#   2 dosya tek build, rollback'li. KULLANIM:
#     scp -i $KEY deploy_yetki_faz5b.sh patch_yetki_faz5b_server.py patch_yetki_faz5b_client.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz5b.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; TA=shells/tenant-admin.js
for f in "$SRV" "$TA" patch_yetki_faz5b_server.py patch_yetki_faz5b_client.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q YETKI_FAZ5 "$TA" || { echo "HATA: YETKI_FAZ5 (renderYetkiDenetim) yok — once Faz5a"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo ROLLBACK; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$TA.bak.$TS" "$TA"; }
python3 patch_yetki_faz5b_server.py "$SRV" || { rollback; exit 1; }
python3 patch_yetki_faz5b_client.py "$TA" || { rollback; exit 1; }
node --check "$TA" || { echo "HATA node (konsol)"; rollback; exit 1; }
cp -a "$SRV" _faz5b_esm.mjs && node --check _faz5b_esm.mjs || { echo "HATA node (server ESM)"; rm -f _faz5b_esm.mjs; rollback; exit 1; }
rm -f _faz5b_esm.mjs; echo "[ok] syntax"
# ── DDL (build'den once; loglama tabloyu bekler) ──
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || { echo "HATA DDL"; rollback; exit 1; }
\set ON_ERROR_STOP on
CREATE TABLE IF NOT EXISTS tenant_yetki_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id uuid NOT NULL,
  actor_id uuid,
  target_user_id uuid,
  department_id uuid,
  eylem text NOT NULL,
  detay jsonb DEFAULT '{}'::jsonb,
  ts timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_yetki_log_tenant_ts ON tenant_yetki_log (tenant_id, ts DESC);
SELECT to_regclass('public.tenant_yetki_log') AS tablo;
SQL
echo "[db] tenant_yetki_log hazır"
docker build -t krb-assessment:secure . >/tmp/faz5b_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/faz5b_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] _yetkiLog cagri (3): ";     docker exec "$CID" grep -c 'await _yetkiLog(' /app/server.mjs || true
echo -n "[srv] yetki-log ucu (1): ";       docker exec "$CID" grep -c '/api/tenant/yetki-log' /app/server.mjs || true
echo -n "[ta] renderYetkiLog (1): ";       docker exec "$CID" grep -c 'async function renderYetkiLog' /app/shells/tenant-admin.js || true
echo -n "[ta] Izinler nav kaldı (0): ";    docker exec "$CID" grep -c 'navBtn(\"permissions\"' /app/shells/tenant-admin.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ5B',
 'Yetki degisiklik gunlugu (denetim, 5b): DDL tenant_yetki_log(id,tenant_id,actor_id,target_user_id,department_id,eylem,detay,ts) + server _yetkiLog helper + 3 yazma-yoluna log (Kisiler PATCH=kisi_yetki, Bolumler apply=bolum_uygula, uyelik=uyelik) + GET /api/tenant/yetki-log (aktor/hedef/bolum isim cozumlu). Konsol Denetim>Yetki Gunlugu gorunumu (zaman/kim/eylem/hedef/detay, renk-kodlu eylem). Ayrica eski Izinler grid nav dan kaldirildi (Bolumler/Kisiler/Roller/Denetim yerini aldi; renderPermissions kod olarak durur). Stiller yl-*.',
 'derive-yetki-toparlama.md Faz 5b. Kim kime ne zaman ne verdi/aldi izlenebilsin (denetim). Fatih: eski Izinler tab hala listede -> kaldirildi (dorduncu editor kafa karisikligi).',
 '{"marker":"YETKI_FAZ5B","tur":"yetki","yuzey":["server","tenant-admin.js"],"tablo":"tenant_yetki_log","uc":"/api/tenant/yetki-log","log_eylem":["kisi_yetki","bolum_uygula","uyelik"],"izinler_nav":"kaldirildi"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ5B');
UPDATE bi_yetenek SET ne_ise_yarar='Yetki degisiklik denetim gunlugu: kim(actor) kime/nereye(target_user/department) ne zaman(ts) hangi eylemi(kisi_yetki/bolum_uygula/uyelik) yapti + detay jsonb.', nasil='server _yetkiLog 3 yazma-yolundan INSERT; GET /api/tenant/yetki-log okur; konsol Denetim>Yetki Gunlugu.', cekmece='yetki', durum='canli', guven='yuksek', aktif=true, guncellendi_at=now() WHERE ad='tenant_yetki_log';
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, aktif)
SELECT 'tenant-yetki-log', 'uc', 'Yetki denetim gunlugunu okur (kim/kime/ne zaman/ne).', 'GET /api/tenant/yetki-log?user=&limit= (requireTenantAdmin), tenant_yetki_log + users/tenant_department join.', 'yetki', 'canli', 'yuksek', true
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant-yetki-log');
SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ5B') insa, (SELECT count(*) FROM bi_yetenek WHERE ad IN ('tenant_yetki_log','tenant-yetki-log')) yetenek;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ5B CANLI — Denetim > Yetki Günlüğü (bundan sonraki değişiklikler loglanır). Eski İzinler tab kaldırıldı. (hard-refresh)"
