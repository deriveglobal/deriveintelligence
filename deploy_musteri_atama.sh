#!/usr/bin/env bash
# MUSTERI_ATAMA_V1 — Yönetim konsolu › Müşteri Atama (sorumlu temsilci yönetimi).
#   Server: 3 endpoint (/api/tenant/musteri-atama GET/POST + /gecmis). Konsol: nav+panel.
#   saha_musteri_aksiyon.eski_rep kolonu (eski->yeni log). Idempotent + rollback. Tek build.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_musteri_atama.sh patch_musteri_atama_server.py patch_musteri_atama_console.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_atama.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; CON=shells/tenant-admin.js
for f in "$SRV" "$CON"; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
for p in patch_musteri_atama_server.py patch_musteri_atama_console.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q "requireTenantAdmin" "$SRV" || { echo "HATA: requireTenantAdmin yok"; exit 1; }
grep -q "PATCH /api/tenant/users/:id/modules" "$SRV" || { echo "HATA: server anchor yok"; exit 1; }
grep -q "renderInvite" "$CON" || { echo "HATA: konsol renderInvite yok"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$CON" "$CON.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$CON.bak.$TS" "$CON"; }
python3 patch_musteri_atama_server.py  "$SRV" || { rollback; exit 1; }
python3 patch_musteri_atama_console.py "$CON" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$CON" || { echo "HATA konsol node"; rollback; exit 1; }
cp "$CON" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm konsol"; rollback; exit 1; }
echo "[ok] syntax (server + konsol)"
# eski_rep kolonu (log icin) — build oncesi
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
  "ALTER TABLE saha_musteri_aksiyon ADD COLUMN IF NOT EXISTS eski_rep uuid;" || { echo "HATA: ALTER"; rollback; exit 1; }
docker build -t krb-assessment:secure . >/tmp/ata_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ata_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server MUSTERI_ATAMA_V1: "; docker exec "$CID" grep -c MUSTERI_ATAMA_V1 /app/server.mjs || true
echo -n "[dogrula] konsol MUSTERI_ATAMA_V1: "; docker exec "$CID" grep -c MUSTERI_ATAMA_V1 /app/shells/tenant-admin.js || true
echo -n "[dogrula] eski_rep kolonu: "; docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc \
  "SELECT count(*) FROM information_schema.columns WHERE table_name='saha_musteri_aksiyon' AND column_name='eski_rep';" || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_ATAMA_V1',
 'Yonetim konsolu > Musteri Atama: sorumlu temsilci yonetimi. 3 endpoint (/api/tenant/musteri-atama GET liste, POST toplu/tekil ata, /gecmis). Mevcut sorumlu_rep varsayilan; tek+toplu degistir; atama gecmisi (eski->yeni, kim, ne zaman). saha_musteri_aksiyon.eski_rep kolonu.',
 'Excel ziyaret defterinden gelen sahiplik (first-importer-wins) yoneticinin tek yerden degistirebilecegi bir panele baglandi. Ziyaret gecmisi dokunulmaz (saha_ziyaret.rep_id sabit), yalniz ileriki sorumluluk degisir.',
 '{"uc":["/api/tenant/musteri-atama","/api/tenant/musteri-atama/gecmis"],"marker":"MUSTERI_ATAMA_V1","kolon":"saha_musteri_aksiyon.eski_rep","surface":"tenant-admin > Müşteri Atama"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_ATAMA_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'tenant_musteri_atama','uc',
 'Yonetici musteri->temsilci atamasini yonetir: tum aktif musteri + sorumlu, tek/toplu degistir, atama gecmisi (eski->yeni). Mevcut sorumlu_rep varsayilan. Tip=toptan(TUKETICI)/filo(TICARI) ve segment gorunur (SAP/saha verisi).',
 'GET /api/tenant/musteri-atama (liste), POST (musteri_ids[],hedef_rep), GET /gecmis?musteri_id (requireTenantAdmin). UPDATE saha_musteri.sorumlu_rep + saha_musteri_aksiyon log (eski_rep+hedef_rep).',
 'yonetim','canli','taslak',
 '{"marker":"MUSTERI_ATAMA_V1","surface":"tenant-admin"}'::jsonb,
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant_musteri_atama');

SELECT 'insa_gunlugu' k, count(*) n FROM bi_insa_gunlugu WHERE adim='MUSTERI_ATAMA_V1'
UNION ALL SELECT 'bi_yetenek', count(*) FROM bi_yetenek WHERE ad='tenant_musteri_atama';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_ATAMA_V1 CANLI — Yönetim (sağ alt) › Müşteriler › Atama. Hard-refresh."
