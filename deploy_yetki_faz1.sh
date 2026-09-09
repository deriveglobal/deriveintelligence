#!/usr/bin/env bash
# YETKI_FAZ1 — Müşteri Kartı pilotu: kart iç bölümlerini matris-tabanlı 'musterikart' capability'ye bağla.
#   Dosyalar: server_container.mjs (+_sahaCap, merkezi kapı muafiyeti, 6 uç musterikart) · shells/saha.js
#   (_yetki + 7 kapı) · shells/tenant-admin.js (rep+manager DEFAULTS'a musterikart).
#   Sıra: patch → syntax → build → BACKFILL (grant, enforcement öncesi) → recreate → doğrula → fingerprint.
#   Rollback'li (3 dosya), tek build, idempotent. Client==server, deny-by-default.
# KULLANIM: scp -i $KEY deploy_yetki_faz1.sh patch_yetki_faz1_server.py patch_yetki_faz1_client.py patch_yetki_faz1_tenantadmin.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz1.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; MOB=shells/saha.js; TA=shells/tenant-admin.js
for f in "$SRV" "$MOB" "$TA" patch_yetki_faz1_server.py patch_yetki_faz1_client.py patch_yetki_faz1_tenantadmin.py; do
  [ -f "$f" ] || { echo "HATA: yok $f"; exit 1; }
done
grep -q "YETKI_FAZ0" "$MOB" || echo "[uyari] saha.js'te YETKI_FAZ0 izi yok — yine de devam (idempotent)"
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; cp -a "$TA" "$TA.bak.$TS"
echo "[yedek] .bak.$TS x3"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$MOB.bak.$TS" "$MOB"; cp -a "$TA.bak.$TS" "$TA"; }
python3 patch_yetki_faz1_server.py "$SRV"      || { rollback; exit 1; }
python3 patch_yetki_faz1_client.py "$MOB"      || { rollback; exit 1; }
python3 patch_yetki_faz1_tenantadmin.py "$TA"  || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA node srv"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA node cli"; rollback; exit 1; }
node --check "$TA"  || { echo "HATA node ta";  rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax x3"
docker build -t krb-assessment:secure . >/tmp/faz1_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz1_build.log; rollback; exit 1; }

echo "[backfill] musterikart -> dolu departments'li aktif saha kullanicilari (enforcement ONCESI)"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || { echo "BACKFILL HATASI"; rollback; exit 1; }
SELECT count(*) AS oncesi_dolu_musterikartsiz
FROM tenant_user_modules
WHERE module_id='saha' AND active=true
  AND jsonb_array_length(COALESCE(permissions_json->'departments','[]'::jsonb)) > 0
  AND NOT (COALESCE(permissions_json->'departments','[]'::jsonb) @> '["musterikart"]'::jsonb);

UPDATE tenant_user_modules
SET permissions_json = jsonb_set(
      COALESCE(permissions_json,'{}'::jsonb), '{departments}',
      (permissions_json->'departments') || '["musterikart"]'::jsonb)
WHERE module_id='saha' AND active=true
  AND jsonb_array_length(COALESCE(permissions_json->'departments','[]'::jsonb)) > 0
  AND NOT (COALESCE(permissions_json->'departments','[]'::jsonb) @> '["musterikart"]'::jsonb);

SELECT count(*) AS musterikartli_toplam
FROM tenant_user_modules
WHERE module_id='saha' AND active=true
  AND (COALESCE(permissions_json->'departments','[]'::jsonb) @> '["musterikart"]'::jsonb);
SQL

docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server _sahaCap (1): ";      docker exec "$CID" grep -c 'function _sahaCap' /app/server.mjs || true
echo -n "[dogrula] server musterikart uc (6): "; docker exec "$CID" grep -oc '_sahaCap([a-z_]*, \"musterikart\")' /app/server.mjs 2>/dev/null || docker exec "$CID" sh -c "grep -o '_sahaCap([a-z_]*, \"musterikart\")' /app/server.mjs | wc -l" || true
echo -n "[dogrula] client _yetki (1): ";         docker exec "$CID" grep -c 'function _yetki(id)' /app/shells/saha.js || true
echo -n "[dogrula] client musterikart kapi (7): ";docker exec "$CID" sh -c "grep -o '_yetki(\"musterikart\")' /app/shells/saha.js | wc -l" || true
echo -n "[dogrula] tenant-admin default (2): ";   docker exec "$CID" sh -c "grep -o '\"musteriler\", \"musterikart\"' /app/shells/tenant-admin.js | wc -l" || true

docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ1',
 'Musteri Karti pilotu: kart ic bolumleri (skor/kiyas/akilli-fiyat/AI-ozet/mesaj) artik matris-tabanli musterikart capability ile aciliyor (gomulu manager/admin degil). Client _yetki + server _sahaCap (client==server, bos-departments rol fallback, admin bypass). /api/bi 4 kart ucu merkezi sales kapisindan muaf; 6 uc musterikart enforce; digerleri (marj/finansal) korundu. tenant-admin DEFAULTS rep+manager musterikart. Backfill: dolu-departments aktif saha kullanicilarina musterikart (bos olanlar rol-fallback korundu).',
 'derive-yetki-toparlama.md Faz 1. Hardcode/bypass yerine tek capability; matris tek dogruluk kaynagi. Backfill enforcement oncesi (lockout yok).',
 '{"marker":"YETKI_FAZ1","tur":"izin","capability":"musterikart","uc":["/api/bi/musteri-skor","/api/bi/musteri-kiyas","/api/bi/musteri-fiyat-liste","/api/bi/ebat-ara","/api/saha/ai/musteri-ozeti/:id","/api/saha/musteri/:id/mesaj"],"client":"saha.js _yetki 7 kapi","fonksiyon":["_sahaCap","_yetki"],"plan":"derive-yetki-toparlama.md"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'musterikart-yetki','fonksiyon',
 'Musteri karti ic istihbarat bolumlerinin (Musteri Skoru, Firma Kiyas, Akilli Fiyat, AI Ozet, Sorumluya Mesaj) yetki kapisi. Matris-tabanli, client==server, deny-by-default. Bir kullanici bu bolumleri ancak departments[] icinde musterikart varsa (veya bos=rol fallback / admin) gorur ve API cekebilir.',
 'saha modulu permissions_json.departments[] icine musterikart. Client _yetki("musterikart"), server _sahaCap(sess,"musterikart"). Yonetim > Izinler matrisinden ac/kapat.',
 'yetki','canli','taslak',
 '{"marker":"YETKI_FAZ1","capability":"musterikart","uc":["/api/bi/musteri-skor","/api/bi/musteri-kiyas","/api/bi/musteri-fiyat-liste","/api/bi/ebat-ara","/api/saha/ai/musteri-ozeti/:id","/api/saha/musteri/:id/mesaj"]}'::jsonb,
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='musterikart-yetki');

SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ1') AS insa,
       (SELECT count(*) FROM bi_yetenek WHERE ad='musterikart-yetki') AS yetenek;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ1 CANLI — kart artik matristen (musterikart). Reps/muduerler gorur; Izinler'den kapatilabilir. iPhone: oldur-ac."
