#!/usr/bin/env bash
# MUSTERI_KART_CLEAN_V1 — mobil müşteri kartını beğenilen sade mock'a çek (yalnız saha.js). Rollback'li.
#   (a) firma adı kesik fix: sabit üst boşluk (env yerine max(46px,…)).
#   (b) ikincil bölümler <details> ile varsayılan KAPALI akordeon: Müşteri detayı & düzenle / Akıllı Fiyat / Lokasyonlar.
#   Hiçbir bölüm silinmez — dokunulunca açılır, tüm loader/veri aynen çalışır.
# KULLANIM: scp -i $KEY deploy_musteri_kart_clean.sh patch_musteri_kart_clean.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_kart_clean.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] && [ -f patch_musteri_kart_clean.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "MUSTERI_KART_WARM_V1" "$MOB" || { echo "HATA: önce MUSTERI_KART_WARM_V1 olmalı"; exit 1; }
TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_musteri_kart_clean.py "$MOB" || { rollback; exit 1; }
node --check "$MOB" || { echo "HATA node"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/clean_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/clean_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] CLEAN_V1: "; docker exec "$CID" grep -c MUSTERI_KART_CLEAN_V1 /app/shells/saha.js || true
echo -n "[dogrula] akordeon (mk mk-acc, 3 olmalı): "; docker exec "$CID" grep -c 'class="mk mk-acc"' /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_KART_CLEAN_V1',
 'Mobil musteri karti begenilen sade mock yapisina cekildi: (a) firma adi kesik fix = sabit ust bosluk max(46px, 14px+env) [iOS viewport-fit=cover yok, env=0 donuyordu]; (b) ikincil bolumler <details> ile varsayilan KAPALI akordeon (Musteri detayi & duzenle = VKN/konum/iletisim/ziyaret/skor/kiyas; Akilli Fiyat; Lokasyonlar). Kart artik intel -> takip -> Tip/Durum/ERP -> Finansal -> Hareketler sade acilir. Hicbir bolum silinmedi.',
 'OLAYLAR+WARM ust istihbarati ekledi ama tum agir bolumler altta kaldi -> kart eskisiyle ayni gorunuyordu ve firma adi hala kesikti. Mock = sade; canli = yigin. Yapisal birlestirme.',
 '{"marker":"MUSTERI_KART_CLEAN_V1","yuzey":"saha.js musteriDetayModal","yontem":"details akordeon + sabit ust bosluk","kapali_varsayilan":["musteri-detay","akilli-fiyat","lokasyonlar"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_CLEAN_V1');
SELECT count(*) clean FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_CLEAN_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_KART_CLEAN_V1 CANLI. iPhone: Ayarlar>Safari>Web Sitesi Verileri temizle VEYA gizli sekme (client degisti, PWA cache yapiskan)."
