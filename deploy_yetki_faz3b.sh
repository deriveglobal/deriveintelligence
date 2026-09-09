#!/usr/bin/env bash
# YETKI_FAZ3B — Veri kapsamı sızıntı kapatma: _sahaScopeGuard + tekil müşteri GET + finansal/olaylar/not (yalnız server).
#   Kapsamlı kullanıcı ID bilse bile başkasının müşterisini açamaz/çekemez → 404. OPT-IN (admin/tumu → sorgu yok).
#   Ön koşul: YETKI_FAZ3A (_sahaScopeSql) canlı. Rollback'li.
# KULLANIM: scp -i $KEY deploy_yetki_faz3b.sh patch_yetki_faz3b_server.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz3b.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_yetki_faz3b_server.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "YETKI_FAZ3A" "$SRV" || { echo "HATA: canlıda YETKI_FAZ3A yok — önce 3a. DUR."; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_yetki_faz3b_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
node --check "$SRV" || { echo "HATA node"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz3b_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz3b_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] YETKI_FAZ3B: ";        docker exec "$CID" grep -c YETKI_FAZ3B /app/server.mjs || true
echo -n "[dogrula] _sahaScopeGuard (1): "; docker exec "$CID" grep -c 'async function _sahaScopeGuard' /app/server.mjs || true
echo -n "[dogrula] guard enjeksiyon (4): "; docker exec "$CID" sh -c "grep -o '_sahaScopeGuard(session, m\[1\])' /app/server.mjs | wc -l" || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ3B',
 'Veri kapsami sizinti kapatma: _sahaScopeGuard(sess,musteriId) + tekil musteri GET (/api/saha/musteriler/:id) + kart veri uclari (finansal/olaylar/not). Kapsamli kullanici ID bilse bile kapsam disi musteriyi acamaz/cekemez -> 404. OPT-IN: admin/tumu/kapsamsiz -> guard true, sorgu yok. _sahaScopeSql (Faz 3a) yeniden kullanilir.',
 'derive-yetki-toparlama.md Faz 3b. 3a liste pilotunun sizintisini (ID ile dogrudan acma) kapatir. Kalan aggregate raporlar (kapsam/portfoy zaten rep-scope) Faz 3c.',
 '{"marker":"YETKI_FAZ3B","tur":"izin-kapsam","fonksiyon":"_sahaScopeGuard","uc":["/api/saha/musteriler/:id","/finansal","/olaylar","/not"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ3B');
UPDATE bi_yetenek SET ne_ise_yarar=ne_ise_yarar||' [3b: tekil kart uclari guard]', guncellendi_at=now() WHERE ad='saha_veri_kapsami' AND ne_ise_yarar NOT LIKE '%3b%';
SELECT count(*) faz3b FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ3B';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ3B CANLI — kapsam sizintisi kapandi (tekil kart). Kapsamli rep artik baskasinin musterisini ID ile de acamaz."
