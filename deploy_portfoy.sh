#!/usr/bin/env bash
# PORTFOY_V1 — Portföy Sağlığı raporu (server endpoint + masaüstü + mobil sekme)
#   + KAPSAM_SAGLIK — Kapsam rozeti kanonik saha_musteri_saglik view'ine bağlandı (kayiyor/sadik → aktif/soguyor/pasif).
#   Ön koşul: SAHA_SAGLIK_V1 view CANLI (saha_saglik_view.sql daha önce çalıştırıldı).
#   3 dosya, rollback'li, tek build. Fingerprint gömülü.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_portfoy.sh patch_portfoy_server.py patch_portfoy_desktop.py patch_portfoy_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_portfoy.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$SRV" "$DK" "$MOB"; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
for p in patch_portfoy_server.py patch_portfoy_desktop.py patch_portfoy_mobile.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
# ön koşul: kanonik view canlı mı?
VIEW=$(docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc \
  "SELECT count(*) FROM information_schema.views WHERE table_name='saha_musteri_saglik';" 2>/dev/null | tr -d '[:space:]')
[ "$VIEW" = "1" ] || { echo "HATA: saha_musteri_saglik view CANLI DEĞİL — önce saha_saglik_view.sql çalıştır"; exit 1; }
echo "[ok] view saha_musteri_saglik canlı"
grep -q "rapor/kapsam" "$SRV" || { echo "HATA: server kapsam anchor yok"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DK" "$DK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DK.bak.$TS" "$DK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_portfoy_server.py  "$SRV" || { rollback; exit 1; }
python3 patch_portfoy_desktop.py "$DK"  || { rollback; exit 1; }
python3 patch_portfoy_mobile.py  "$MOB" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DK"  || { echo "HATA desktop node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$DK" /tmp/_dk.mjs; node --check /tmp/_dk.mjs || { echo "HATA esm desktop"; rollback; exit 1; }
cp "$MOB" /tmp/_mob.mjs; node --check /tmp/_mob.mjs || { echo "HATA esm mobil"; rollback; exit 1; }
echo "[ok] syntax (server + desktop + mobil)"
docker build -t krb-assessment:secure . >/tmp/pf_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/pf_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server PORTFOY_V1: ";      docker exec "$CID" grep -c PORTFOY_V1 /app/server.mjs || true
echo -n "[dogrula] server KAPSAM_SAGLIK_V1: "; docker exec "$CID" grep -c KAPSAM_SAGLIK_V1 /app/server.mjs || true
echo -n "[dogrula] desktop PORTFOY_DK_V1: ";   docker exec "$CID" grep -c PORTFOY_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil PORTFOY_MOB_V1: ";    docker exec "$CID" grep -c PORTFOY_MOB_V1 /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOY_V1',
 'Portfoy Sagligi raporu: GET /api/saha/rapor/portfoy (rep scope + yonetici rollup). Kanonik saha_musteri_saglik view''inden aktif/soguyor/pasif; ozet + yaslanma bantlari (recency) + risk altindaki ciro + risk listesi (soguyor+pasif, ciroya gore) + temsilci rollup. alim_yok (ERP eslesmemis) AYRI gosterilir, churn''e sayilmaz. Masaustu 🩺 Portfoy sekmesi + mobil sekme.',
 'Wave 3 rep raporu: kendi defterinde kim aliminden kesiliyor, ne kadar ciro risk altinda. Ritim-duyarli (musterinin kendi temposu) — sabit esik yanlis alarm uretiyordu.',
 '{"marker":"PORTFOY_V1","uc":"/api/saha/rapor/portfoy","kaynak":"VIEW saha_musteri_saglik","surface":["saha_desktop","saha.js"],"dept":["rapor"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOY_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'KAPSAM_SAGLIK_V1',
 'Kapsam listesi rozeti kanonik saha_musteri_saglik view''ine baglandi: eski h1r/h2r ikili retention (kayiyor/sadik) KALKTI → aktif/soguyor/pasif (view.durum). Server + masaustu (kap-tk) + mobil (kp-meta). Tek yasa: rozet ile Portfoy Sagligi ayni tanimi okur.',
 'Tutarlilik: iki farkli churn tanimi olmasin. H1/H2 sabit esik topakli B2B''de yanlis; ritim-duyarli view kanonik.',
 '{"marker":"KAPSAM_SAGLIK_V1","kaynak":"VIEW saha_musteri_saglik","onceki":"h1r/h2r KAPSAM_RETENTION_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KAPSAM_SAGLIK_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_rapor_portfoy','rapor',
 'Portfoy Sagligi: rep/yonetici defterinde musteri churn/yaslanma. aktif/soguyor/pasif (ritim-duyarli, kanonik saha_musteri_saglik). Risk altindaki ciro + risk listesi + temsilci rollup. alim_yok (ERP eslesmemis) ayri.',
 'GET /api/saha/rapor/portfoy?tip= (requireSahaAccess, rep sorumlu_rep scope). saha_musteri LEFT JOIN saha_musteri_saglik + 12ay ciro + son ziyaret. JS: durum sayimi, recency bantlari, risk listesi.',
 'saha','canli','taslak',
 '{"marker":"PORTFOY_V1"}'::jsonb, true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_rapor_portfoy');

UPDATE bi_yetenek SET ne_ise_yarar = ne_ise_yarar || ' [KAPSAM_SAGLIK_V1: satir rozeti artik kanonik saha_musteri_saglik durumu — aktif/soguyor/pasif]', guncellendi_at=now(), son_gorulme=now()
WHERE ad='saha_rapor_kapsam' AND ne_ise_yarar NOT LIKE '%KAPSAM_SAGLIK_V1%';

SELECT 'insa_portfoy' k, count(*) n FROM bi_insa_gunlugu WHERE adim='PORTFOY_V1'
UNION ALL SELECT 'insa_saglik', count(*) FROM bi_insa_gunlugu WHERE adim='KAPSAM_SAGLIK_V1'
UNION ALL SELECT 'yetenek_portfoy', count(*) FROM bi_yetenek WHERE ad='saha_rapor_portfoy';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] PORTFOY_V1 CANLI — Saha › 🩺 Portföy. Kapsam rozeti kanonik view'e bağlı. Hard-refresh."
