#!/usr/bin/env bash
# MUSTERI_KART_OLAYLAR_V1 — mobil müşteri kartı: istihbarat başlığı + Hareketler + Not/Takip (yalnız saha.js).
#   Ön koşul: MUSTERI_OLAYLAR_V1 server endpoint CANLI. Rollback'li, tek build.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_musteri_kart_olaylar.sh patch_musteri_kart_olaylar.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_kart_olaylar.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_musteri_kart_olaylar.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "MUSTERI_OLAYLAR_V1" server_container.mjs || { echo "HATA: önce MUSTERI_OLAYLAR_V1 (server) canlı olmalı"; exit 1; }
grep -q "musteriDetayModal" "$MOB" || { echo "HATA: musteriDetayModal yok"; exit 1; }
TS=$(date +%s)
cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_musteri_kart_olaylar.py "$MOB" || { rollback; exit 1; }
node --check "$MOB" || { echo "HATA node"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/kart_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kart_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] MUSTERI_KART_OLAYLAR_V1: "; docker exec "$CID" grep -c MUSTERI_KART_OLAYLAR_V1 /app/shells/saha.js || true
echo -n "[dogrula] _mkYukle: ";                docker exec "$CID" grep -c _mkYukle /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_KART_OLAYLAR_V1',
 'Mobil musteri karti (musteriDetayModal): ust istihbarat basligi (kural-tabanli ozet cumlesi + mini-EKG: alim ritmi + ziyaret + not isaretleri + durum bandi) + acik takip uyarisi + inline Not/Takip formu (neden etiketi + opsiyonel takip tarihi) + Ziyaret Gecmisi -> "Hareketler" (union /olaylar, tip-filtreli, katlanir). Sicak DS palet (scoped .mk*). Mevcut bolumler (finansal/alim/fiyat) korundu.',
 'Musteri karti = tek merkez: bu musteriyle ne oluyor tek bakista + tum olaylar tek akista + rep not/takip girer. Uzun scroll degil: ozet+EKG ustte, ham liste katlanir.',
 '{"marker":"MUSTERI_KART_OLAYLAR_V1","yuzey":"saha.js musteriDetayModal","okur":"/api/saha/musteriler/:id/olaylar","yazar":"/api/saha/musteriler/:id/not","not":"mevcut finansal/alim/fiyat bolumleri slate paletinde kaldi (kozmetik restyle ayri)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_OLAYLAR_V1');
SELECT 'insa' k, count(*) n FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_OLAYLAR_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_KART_OLAYLAR_V1 CANLI — mobil müşteri kartı üstünde istihbarat + Hareketler + Not/Takip. Hard-refresh."
