#!/usr/bin/env bash
# REP_PARITE_V1 — saha temsilcisi müşteri kartında yöneticiyle aynı bilgiyi görür.
#   İki dosya: server_container.mjs (6 endpoint saha rolüne açılır) + shells/saha.js (6 kart kapısı kalkar).
#   Tek build, ikisi de rollback'li. Kapsam DAR: sadece skor/kiyas/fiyat-liste/ebat-ara/ai-ozet/mesaj.
# KULLANIM: scp -i $KEY deploy_rep_parity.sh patch_rep_parity_server.py patch_rep_parity_client.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rep_parity.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
MOB=shells/saha.js
[ -f "$SRV" ] && [ -f "$MOB" ] || { echo "HATA: kaynak dosya yok"; exit 1; }
[ -f patch_rep_parity_server.py ] && [ -f patch_rep_parity_client.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "MUSTERI_KART_CLEAN_V1" "$MOB" || { echo "HATA: önce MUSTERI_KART_CLEAN_V1 olmalı"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $SRV.bak.$TS + $MOB.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$MOB.bak.$TS" "$MOB"; }

python3 patch_rep_parity_server.py "$SRV" || { rollback; exit 1; }
python3 patch_rep_parity_client.py "$MOB" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA node srv"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA node cli"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"

docker build -t krb-assessment:secure . >/tmp/parity_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/parity_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server REP_PARITE_V1 (6 beklenir): "; docker exec "$CID" grep -c REP_PARITE_V1 /app/server.mjs || true
echo -n "[dogrula] client REP_PARITE_V1 (3 yorum beklenir): "; docker exec "$CID" grep -c REP_PARITE_V1 /app/shells/saha.js || true
echo -n "[dogrula] dokunulmayanlar hâlâ kapalı (marj-alarm vb, >0 beklenir): "; docker exec "$CID" grep -c 'includes(_ss.sahaRole)) { sendJson(response, 403' /app/server.mjs || true

docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'REP_PARITE_V1',
 'Saha temsilcisi (rep) musteri kartinda yoneticiyle AYNI bilgiyi gorur. Acilan: Musteri Skoru, Kiyas, Akilli Fiyat Onerisi, Son Alim ''odedigi->onerilen'' sutunu, AI Ozeti, Mesaj butonu. Server: /api/bi/musteri-skor, /api/bi/musteri-fiyat-liste, /api/bi/musteri-kiyas, /api/bi/ebat-ara, /api/saha/ai/musteri-ozeti/:id, /api/saha/musteri/:id/mesaj endpointlerinde manager/admin kapisi kaldirildi (auth requireSahaAccess/_sess korunur). Client: saha.js musteriDetayModal 6 rol kapisi kaldirildi.',
 'Fatih karari: rep = yonetici, ayni gorsun. Kisitlar eski (SMARTFIYAT/SMARTKIYAS) kararlardandi, yeni degildi. DAR kapsam: marj-alarm/musteri-fiyat/iyilestirme-hedefleri/marj-alarm-desen/ebat-kart DOKUNULMADI.',
 '{"marker":"REP_PARITE_V1","tur":"izin","acilan_endpointler":["/api/bi/musteri-skor","/api/bi/musteri-fiyat-liste","/api/bi/musteri-kiyas","/api/bi/ebat-ara","/api/saha/ai/musteri-ozeti/:id","/api/saha/musteri/:id/mesaj"],"client":"saha.js musteriDetayModal 6 kapi","dokunulmayan":["marj-alarm","musteri-fiyat","iyilestirme-hedefleri","marj-alarm-desen","ebat-kart"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='REP_PARITE_V1');
SELECT count(*) parite FROM bi_insa_gunlugu WHERE adim='REP_PARITE_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] REP_PARITE_V1 CANLI — rep artik yoneticiyle ayni karti gorur. iPhone: uygulamayi oldur-ac (WebView cache)."
