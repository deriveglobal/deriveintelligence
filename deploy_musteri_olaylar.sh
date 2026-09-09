#!/usr/bin/env bash
# MUSTERI_OLAYLAR_V1 — müşteri zaman çizelgesi (union) + not/takip yazma (yalnız server).
#   GET /api/saha/musteriler/:id/olaylar (salt-okuma union) + POST .../not (saha_sinyal INSERT).
#   Yeni tablo/DDL YOK. Görünür UI değişikliği YOK (kart ayrı deploy). Rollback'li, tek build.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_musteri_olaylar.sh patch_musteri_olaylar_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_olaylar.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_musteri_olaylar_server.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "saha_musteri_saglik" "$SRV" || { echo "HATA: saha_musteri_saglik referansı yok (KAPSAM_SAGLIK canlı olmalı)"; exit 1; }
VIEW=$(docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc \
  "SELECT count(*) FROM information_schema.views WHERE table_name='saha_musteri_saglik';" 2>/dev/null | tr -d '[:space:]')
[ "$VIEW" = "1" ] || { echo "HATA: saha_musteri_saglik view canlı değil"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; }
python3 patch_musteri_olaylar_server.py "$SRV" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/olay_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/olay_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] MUSTERI_OLAYLAR_V1: "; docker exec "$CID" grep -c MUSTERI_OLAYLAR_V1 /app/server.mjs || true
echo -n "[dogrula] /olaylar rota: ";        docker exec "$CID" sh -c "grep -c '/olaylar' /app/server.mjs || true"
echo -n "[dogrula] /not rota: ";            docker exec "$CID" sh -c "grep -c 'musteriler/(.*)/not' /app/server.mjs || true"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_OLAYLAR_V1',
 'Musteri zaman cizelgesi (union) + not/takip yazma. GET /api/saha/musteriler/:id/olaylar tum kaynaklari harmanlar (ziyaret+sinyal+aksiyon+alim+teklif+rakip) + kural-tabanli ozet cumlesi + EKG verisi + sayaclar + acik takipler + ritim-turevi durum (saha_musteri_saglik). POST .../not saha_sinyal INSERT (tip=not/takip, detay.neden+takip_tarihi) + saha_musteri_aksiyon log. Yeni tablo/DDL YOK, salt-okuma union + sadece-ekleme yazma.',
 'Musteri karti = tek merkez: her yuzeyden o musteriye ait her sey tek kronolojik akista gorulsun (Fatih). Var olan tablolar birlestirilir, hicbir sey tasinmaz/silinmez.',
 '{"marker":"MUSTERI_OLAYLAR_V1","uc":["/api/saha/musteriler/:id/olaylar","/api/saha/musteriler/:id/not"],"kaynaklar":["saha_ziyaret","saha_sinyal","saha_musteri_aksiyon","saha_teklif","saha_rakip_teklif","bi_satis_faturalari","saha_musteri_saglik"],"yazma":"saha_sinyal + saha_musteri_aksiyon (INSERT-only)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_OLAYLAR_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_musteri_olaylar','uc',
 'Musteri zaman cizelgesi: bir musteriye ait tum olaylar (ziyaret/alim/not/teklif/rakip/aksiyon/durum) tek kronolojik akista + kural-tabanli ozet cumlesi + EKG + sayaclar + acik takipler. Musteri karti istihbarat basligi + Hareketler bunu okur.',
 'GET /api/saha/musteriler/:id/olaylar (requireSahaAccess, her rep her musteri). Union: saha_ziyaret+saha_sinyal+saha_musteri_aksiyon+saha_teklif+saha_rakip_teklif+bi_satis_faturalari(kodla)+saha_musteri_saglik. Isim cozumu users. Salt-okuma.',
 'saha','canli','taslak','{"marker":"MUSTERI_OLAYLAR_V1"}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_musteri_olaylar');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_musteri_not','uc',
 'Rep musteri kartina not/takip girer; saha_sinyal (tip=not/takip, detay.neden+takip_tarihi) + saha_musteri_aksiyon loguna yazilir. Zaman cizelgesinde gorunur; acik takip vadesi gelince one cikar.',
 'POST /api/saha/musteriler/:id/not {metin,neden?,takip_tarihi?} (requireSahaAccess). INSERT-only, mevcut saha_sinyal tablosu (Voice-of-Field/INTENT altyapisi).',
 'saha','canli','taslak','{"marker":"MUSTERI_OLAYLAR_V1"}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_musteri_not');

SELECT 'insa' k, count(*) n FROM bi_insa_gunlugu WHERE adim='MUSTERI_OLAYLAR_V1'
UNION ALL SELECT 'yetenek_olaylar', count(*) FROM bi_yetenek WHERE ad='saha_musteri_olaylar'
UNION ALL SELECT 'yetenek_not', count(*) FROM bi_yetenek WHERE ad='saha_musteri_not';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_OLAYLAR_V1 CANLI (server) — olaylar union + not/takip. UI kart ayrı deploy."
