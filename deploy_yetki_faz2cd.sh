#!/usr/bin/env bash
# YETKI_FAZ2CD — Yönetim'e Kişiler editörü (kişi-merkezli) + Roller referansı + tümünü-seç (yalnız tenant-admin.js).
#   Eski "İzinler" ızgarası KALIR (bir arada). Kaydet = saveRow ile aynı PATCH /api/tenant/users/:id/modules.
#   Rollback'li, tek build. Ön koşul: taze 2b'li tenant-admin.js.
# KULLANIM: scp -i $KEY deploy_yetki_faz2cd.sh patch_yetki_faz2cd_tenantadmin.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz2cd.sh'
set -euo pipefail
cd /opt/krb-assessment
TA=shells/tenant-admin.js
[ -f "$TA" ] && [ -f patch_yetki_faz2cd_tenantadmin.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "YETKI_FAZ2B" "$TA" || { echo "HATA: canlıda YETKI_FAZ2B yok — taze 2b'li dosya değil (clobber/cache?). DUR."; exit 1; }
TS=$(date +%s); cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] $TA.bak.$TS"
python3 patch_yetki_faz2cd_tenantadmin.py "$TA" || { cp -a "$TA.bak.$TS" "$TA"; exit 1; }
node --check "$TA" || { echo "HATA node"; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz2cd_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz2cd_build.log; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] YETKI_FAZ2CD: ";     docker exec "$CID" grep -c YETKI_FAZ2CD /app/shells/tenant-admin.js || true
echo -n "[dogrula] renderKisiler (2): "; docker exec "$CID" grep -c 'renderKisiler' /app/shells/tenant-admin.js || true
echo -n "[dogrula] nav kisiler+roller (2): "; docker exec "$CID" sh -c "grep -o 'navBtn(\"kisiler\"\|navBtn(\"roller\"' /app/shells/tenant-admin.js | wc -l" || true
echo -n "[dogrula] 2b hâlâ (renderBolumler>=1): "; docker exec "$CID" grep -c 'renderBolumler' /app/shells/tenant-admin.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ2CD',
 'Yonetim > Kisiler editoru (kisi-merkezli: ara + modul sekmesi + rol sablonu baz + katlanir gruplar toggle + sablon/ozel etiketi + grup master + tumunu sec/temizle -> Kaydet, saveRow ile ayni PATCH /api/tenant/users/:id/modules) + Roller referansi (rol varsayilan setleri, salt-okunur). Eski Izinler izgarasi KALIR (bir arada). Stiller taStyles tk-*/tr-* (gomme yok).',
 'derive-yetki-toparlama.md Faz 2c/2d. Uzun-scroll dev izgara yerine kisi-merkezli editor; tumunu-sec.',
 '{"marker":"YETKI_FAZ2CD","tur":"ui","yuzey":"tenant-admin.js Kisiler+Roller","kullanir":["/api/tenant/users","/api/tenant/users/:id/modules"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ2CD');
SELECT count(*) faz2cd FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ2CD';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ2CD CANLI — Yönetim > Kişiler + Roller. Masaüstü konsol; hard-refresh."
