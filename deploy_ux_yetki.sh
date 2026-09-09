#!/usr/bin/env bash
# UX_YETKI_V1 — Bolumler tek-tik uygula (acik uye panelini de kaydet) + Kisiler bolum/kisisel rozeti. Yalniz tenant-admin.js.
#   + tenant_yetki_log bi_yetenek enrich (Faz5b'de UPDATE 0 kalan kor kaydi kapat). DB yapisal degisiklik YOK. Rollback'li.
#   KULLANIM:
#     scp -i $KEY deploy_ux_yetki.sh patch_ux_yetki_client.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ux_yetki.sh'
set -euo pipefail
cd /opt/krb-assessment
TA=shells/tenant-admin.js
[ -f "$TA" ] && [ -f patch_ux_yetki_client.py ] || { echo "HATA: dosya yok"; exit 1; }
TS=$(date +%s); cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] $TA.bak.$TS"
python3 patch_ux_yetki_client.py "$TA" || { cp -a "$TA.bak.$TS" "$TA"; exit 1; }
node --check "$TA" || { echo "HATA node"; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/ux_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/ux_build.log; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[ta] UX_YETKI_V1 (3): ";        docker exec "$CID" grep -c UX_YETKI_V1 /app/shells/tenant-admin.js || true
echo -n "[ta] member-autosave (1): ";    docker exec "$CID" grep -c 'bekleyen uyelik degisikligini' /app/shells/tenant-admin.js || true
echo -n "[ta] rozet kişisel (1): ";      docker exec "$CID" grep -c 'tk-tag ovr\">kişisel' /app/shells/tenant-admin.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'UX_YETKI_V1',
 'Yetki UX cilasi (tenant-admin.js, client-only): (1a) Bolumler "Kaydet & uygula" acik uye panelini de otomatik kaydeder (tek tik; onceki 2-adim "0 uyeye uygulandi" karisikligi bitti). (1b) Kisiler rozeti "sablon/ozel" -> "bolum/kisisel" (personal_grant''e gore, Faz4 modeliyle dogru).',
 'derive-yetki-toparlama.md kalan UX. Fatih daha once uye-kaydet + uygula ayri oldugu icin "0 uyeye uygulandi" yasadi.',
 '{"marker":"UX_YETKI_V1","tur":"ux","yuzey":"tenant-admin.js","degisiklik":["bolumler_tek_tik_uygula","kisiler_bolum_kisisel_rozet"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='UX_YETKI_V1');
-- Faz5b kor kaydi kapat: tenant_yetki_log bi_yetenek (yoksa ekle, varsa enrich)
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, aktif)
SELECT 'tenant_yetki_log', 'tablo',
 'Yetki degisiklik denetim gunlugu tablosu: actor/target_user/department + eylem(kisi_yetki/bolum_uygula/uyelik) + detay jsonb + ts.',
 'server _yetkiLog 3 yazma-yolundan INSERT; GET /api/tenant/yetki-log okur; konsol Denetim>Yetki Gunlugu.',
 'yetki', 'canli', 'yuksek', true
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant_yetki_log');
UPDATE bi_yetenek SET tur='tablo', ne_ise_yarar='Yetki degisiklik denetim gunlugu tablosu: actor/target_user/department + eylem + detay jsonb + ts.', durum='canli', guven='yuksek', aktif=true, cekmece='yetki', guncellendi_at=now() WHERE ad='tenant_yetki_log';
SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='UX_YETKI_V1') insa, (SELECT durum FROM bi_yetenek WHERE ad='tenant_yetki_log') log_durum;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] UX_YETKI_V1 CANLI — Bölümler tek tıkla uygular; Kişiler'de bölüm/kişisel rozeti. (hard-refresh)"
