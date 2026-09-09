#!/usr/bin/env bash
# OMURGA 48 DEPLOY — öğrenme endpoint yaması + syntax + build + recreate + halka kanıtı
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YAMA (endpoint ekle)"
cp server_container.mjs server_container.mjs.bak_o48
python3 patch_ogrenme_endpoint.py || { echo "  ❌ yama başarısız"; exit 1; }

hr "2. SYNTAX (node --check) — kırıksa geri al"
if ! node --check server_container.mjs; then
  echo "  ❌ syntax hatası — geri alınıyor"; cp server_container.mjs.bak_o48 server_container.mjs; exit 1; fi
echo "  ✅ syntax temiz"

hr "3. BUILD + RECREATE (docker cp YASAK; footprint boot'ta çalışır)"
docker build -t krb-assessment:secure . >/tmp/o48build.log 2>&1 && echo "  ✅ build" || { echo "  ❌ build — son 20 satır:"; tail -20 /tmp/o48build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1 && echo "  ✅ recreate" || { echo "  ❌ recreate"; exit 1; }
sleep 6

hr "4. HALKA KANITI — test sorusunu cevapla, sonra ogren_bilinen hatırlıyor mu"
$PSQL -c "UPDATE bi_sistem_sorusu SET cevap='Bilinçli düşük-marj hacim büyüttük (test cevabı)', cevap_zamani=now(), durum='cevaplandi'
  WHERE tenant_id='$T'::uuid AND anahtar='marj-ek-baglam:CONTINENTAL' AND durum='acik';" 2>&1 | sed 's/^/  /'
echo "  → ogren_bilinen döndürüyor mu:"
$PSQL -c "SELECT COALESCE(ogren_bilinen('$T'::uuid,'marj-ek-baglam:CONTINENTAL'),'(boş!)') AS hatirladigi;" 2>&1 | sed 's/^/  /'

hr "5. DEFTER — 2 yeni endpoint'i taslak-tanımla (footprint tanımsız kaydeder)"
$PSQL -c "UPDATE bi_yetenek SET ne_ise_yarar=v.a, cekmece='ogrenme', durum='taslak', guven='taslak'
  FROM (VALUES ('/api/bi/sistem-soru','Sistemin açık sorularını gösterir (öğrenme döngüsü — gör).'),
               ('/api/bi/sistem-soru-cevap','Sistem sorusunu cevaplar → durum=cevaplandi, ogren_bilinen hatırlar (öğren).')
       ) v(ad,a) WHERE bi_yetenek.ad=v.ad AND bi_yetenek.tur='endpoint';" 2>&1 | sed 's/^/  /'

hr "6. SAĞLIK"
docker ps --filter name=krb-assessment --format '  {{.Names}} {{.Status}}'

hr "BITTI — sor→cevapla→hatırla halkası CANLI. Kalan: araştırıcı honest-null'da ogren_sor çağırsın + UI kartı."
