#!/usr/bin/env bash
# YETKI_FAZ2B — Yönetim › Bölümler sekmesi UI (yalnız shells/tenant-admin.js). Rollback'li, tek build.
#   Bölüm listesi + şablon editörü (yetenek toggle) + veri-kapsamı seçici (saklanır, Faz3 zorlar) +
#   üye yönet + "N üyeye uygula". Stiller taStyles()'a (gömme yok). + Faz1 DEFAULTS heal (clobber geri koy).
#   Ön koşul: YETKI_FAZ2A (server uçları) canlı.
# KULLANIM: scp -i $KEY deploy_yetki_faz2b.sh patch_yetki_faz2b_tenantadmin.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz2b.sh'
set -euo pipefail
cd /opt/krb-assessment
TA=shells/tenant-admin.js
[ -f "$TA" ] && [ -f patch_yetki_faz2b_tenantadmin.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "YETKI_FAZ2A" server_container.mjs || echo "[uyari] server'da YETKI_FAZ2A yok — Bölümler uçları 404 verebilir (önce 2a)"
TS=$(date +%s); cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] $TA.bak.$TS"
python3 patch_yetki_faz2b_tenantadmin.py "$TA" || { cp -a "$TA.bak.$TS" "$TA"; exit 1; }
node --check "$TA" || { echo "HATA node"; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz2b_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz2b_build.log; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] YETKI_FAZ2B: ";       docker exec "$CID" grep -c YETKI_FAZ2B /app/shells/tenant-admin.js || true
echo -n "[dogrula] renderBolumler (1): "; docker exec "$CID" grep -c 'async function renderBolumler' /app/shells/tenant-admin.js || true
echo -n "[dogrula] nav bolumler (1): ";   docker exec "$CID" grep -c 'navBtn("bolumler"' /app/shells/tenant-admin.js || true
echo -n "[dogrula] tb-wrap stil (1): ";   docker exec "$CID" grep -c '.tb-wrap{' /app/shells/tenant-admin.js || true
echo -n "[dogrula] DEFAULTS heal musterikart (2): "; docker exec "$CID" sh -c "grep -o '\"musteriler\", \"musterikart\"' /app/shells/tenant-admin.js | wc -l" || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ2B',
 'Yonetim > Bolumler sekmesi (tenant-admin.js): bolum listesi + sablon editoru (yetenek toggle MODULES.saha.groups) + veri-kapsami secici (kendi/bolge/bolum/tumu, saklanir Faz3 zorlar) + uye yonet + Kaydet & N uyeye uygula (PATCH template -> POST apply). Stiller taStyles() tb-* (gomme yok). Ayrica Faz1 DEFAULTS heal: rep+manager DEFAULTS musterikart geri kondu (paralel oturum tenant-admin.js full-file swap ile Faz1 degisikligini ezmisti).',
 'derive-yetki-toparlama.md Faz 2b. Org bolum UI. Clobber heal: tenant-admin.js parallel-edited full-file swap.',
 '{"marker":"YETKI_FAZ2B","tur":"ui","yuzey":"tenant-admin.js Bolumler","kullanir":["/api/tenant/departments*"],"heal":"YETKI_FAZ1 DEFAULTS musterikart"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ2B');
SELECT count(*) faz2b FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ2B';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ2B CANLI — Yönetim > Bölümler. Satış/Yönetim'i seç, yetenek+kapsam düzenle, üye ekle, uygula. (masaüstü konsol; hard-refresh)"
