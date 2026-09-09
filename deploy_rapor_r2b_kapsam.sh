#!/usr/bin/env bash
# RAPOR_R2B_KAPSAM — Kural 6 (dedup): Kapsam ciro TOPLAMLARI (beyaz_ciro + sehir + segment + temsilci) ayni musteri_kodu'yu
#   mukerrer saymaz (_ciroD). Sayimlar/liste/sort/isBeyaz DEGISMEZ; yalniz toplamlar dogru yonde (hafif) duser. server-only. Rollback'li.
#   KULLANIM:
#     scp -i $KEY deploy_rapor_r2b_kapsam.sh patch_rapor_r2b_kapsam_server.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_r2b_kapsam.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_rapor_r2b_kapsam_server.py ] || { echo "HATA: dosya yok"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_rapor_r2b_kapsam_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
cp -a "$SRV" _r2bk_esm.mjs && node --check _r2bk_esm.mjs || { echo "HATA node ESM"; rm -f _r2bk_esm.mjs; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
rm -f _r2bk_esm.mjs; echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/r2bk_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/r2bk_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] RAPOR_R2B_KAPSAM (2): ";       docker exec "$CID" grep -c RAPOR_R2B_KAPSAM /app/server.mjs || true
echo -n "[srv] _ciroD toplamda (4): ";        docker exec "$CID" grep -c 'x._ciroD || 0' /app/server.mjs || true
echo -n "[srv] eski mukerrer toplam (0): ";   docker exec "$CID" grep -c 'g.beyaz_ciro += Number(x.ciro)' /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'RAPOR_R2B_KAPSAM',
 'Kapsam raporu Kural 6 dedup (Faz R2b): beyaz_ciro mansetı + sehir + segment + temsilci ciro toplamlari ayni musteri_kodu''yu mukerrer sayiyordu (~%8,6 sisme, saha_musteri_kanon''da kanitlandi: distinct 451M vs dedupsuz 490M). Cozum: satir bazinda _ciroD (ilk kodu gercek ciro, tekrar 0); yalniz TOPLAMLAR _ciroD kullanir. Sayimlar (portfoy/ulasilan/beyaz_sayi) + liste + sort + isBeyaz uyelik degismez.',
 'derive-rapor-denetim.md MED + derive-rapor-kanon.md Kural 6. Toplam ciro DISTINCT kodu uzerinden olmali.',
 '{"marker":"RAPOR_R2B_KAPSAM","tur":"duzeltme","yuzey":"server","rapor":"kapsam","kural":"6-dedup","sisme":"~%8.6"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='RAPOR_R2B_KAPSAM');
SELECT count(*) r2bk FROM bi_insa_gunlugu WHERE adim='RAPOR_R2B_KAPSAM';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] RAPOR_R2B_KAPSAM CANLI — Kapsam ciro toplamlari mukerrersiz (dogru). Beyaz alan cirosu ~%8-9 duser (dogru yon). (hard-refresh)"
