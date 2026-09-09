#!/usr/bin/env bash
# YETKI_FAZ3A — Veri kapsamı PİLOT: _sahaScopeSql + /api/saha/musteriler listesi (yalnız server). Rollback'li.
#   OPT-IN: kapsam ayarsız/tumu/admin → filtre yok (regresyon yok). Sadece Bölümler'den daraltılmış kişi filtrelenir.
#   ⚠ Bu pilot yalnız LİSTE ucu. Tekil kart + diğer müşteri uçları = Faz 3b.
# KULLANIM: scp -i $KEY deploy_yetki_faz3a.sh patch_yetki_faz3a_server.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz3a.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_yetki_faz3a_server.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "YETKI_FAZ2A" "$SRV" || { echo "HATA: canlıda YETKI_FAZ2A yok — taze 2a'lı server değil. DUR."; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_yetki_faz3a_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
node --check "$SRV" || { echo "HATA node"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz3a_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz3a_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] YETKI_FAZ3A (2): ";       docker exec "$CID" grep -c YETKI_FAZ3A /app/server.mjs || true
echo -n "[dogrula] _sahaScopeSql (1): ";      docker exec "$CID" grep -c 'function _sahaScopeSql' /app/server.mjs || true
echo -n "[dogrula] musteriler enjeksiyon (1): "; docker exec "$CID" grep -c 'sql += _sahaScopeSql(session, params, "m")' /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ3A',
 'Veri kapsami zorlamasi PILOT: _sahaScopeSql(sess,params,alias) yardimcisi + /api/saha/musteriler listesine enjekte. OPT-IN: permissions_json.scope.level ayarsiz/tumu/admin -> filtre yok (regresyon yok). kendi->sorumlu_rep=ben; bolge->il=ANY(bolgeler) [bos ise kendi]; bolum->bolum-peer sorumlu_rep; tumu->yok. Kaynak: Bolumler uygula scope yaziyor. Bu pilot yalniz LISTE; tekil kart + diger musteri uclari Faz 3b.',
 'derive-yetki-toparlama.md Faz 3 (satir-seviyesi). Ilk uc pilot, opt-in guvenli. Kapsamli rep listede yalniz kendi musterilerini gorur.',
 '{"marker":"YETKI_FAZ3A","tur":"izin-kapsam","fonksiyon":"_sahaScopeSql","uc":["/api/saha/musteriler(GET liste)"],"opt_in":"scope.level ayarsiz=tumu","kalan":"tekil kart + diger uclar Faz 3b"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ3A');
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_veri_kapsami','fonksiyon','Satir-seviyesi veri kapsami: kullanicinin permissions_json.scope (kendi/bolge/bolum/tumu) uyarinca musteri sorgularina WHERE ekler. Opt-in (tumu=filtre yok). Bolumler uygula scope yazar; Atama sorumlu_rep omurgasi.',
 'server _sahaScopeSql(sess,params,alias); /api/saha/musteriler enjekte (Faz 3a). Faz 3b diger uclara yayilir.','yetki','canli','taslak',
 '{"marker":"YETKI_FAZ3A"}'::jsonb, true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_veri_kapsami');
SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ3A') insa,(SELECT count(*) FROM bi_yetenek WHERE ad='saha_veri_kapsami') yetenek;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ3A CANLI — veri kapsami pilot (liste). Test: bir rep'i Bölümler>Satış'a ekle+uygula (kapsam=kendi) -> o rep müşteri listesinde yalniz kendi müşterilerini görür."
