#!/usr/bin/env bash
# WAVE 3 — Ziyaret→gelir etkisi (Kohort ROI) = "📈 Saha ROI" sekmesi (yönetici).
#   Server:   GET /api/saha/rapor/ziyaret-etki (ZIYARET_ETKI_V1) — kohort ROI + dilim-içi + doz-yanıt.
#   Masaüstü: 📈 Saha ROI sekmesi (ZIYARET_ETKI_DK_V1).
#   Mobil:    📈 Saha ROI sekmesi (ZIYARET_ETKI_MOB_V1).
#   Tek build. Idempotent + hata olursa geri alır. Fingerprint (insa_gunlugu + bi_yetenek) deploy anında.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ziyaret_etki.sh patch_ziyaret_etki_server.py patch_ziyaret_etki_desktop.py patch_ziyaret_etki_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_etki.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$SRV" "$DSK" "$MOB"; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
for p in patch_ziyaret_etki_server.py patch_ziyaret_etki_desktop.py patch_ziyaret_etki_mobile.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
# anchor onkosullari (guard)
grep -q 'path === "/api/saha/rapor/rep-performans"' "$SRV" || { echo "HATA: server rep-performans anchor yok"; exit 1; }
grep -q KAPSAM_DK_V1  "$DSK" || { echo "HATA: masaüstü KAPSAM_DK_V1 yok"; exit 1; }
grep -q KAPSAM_MOB_V1 "$MOB" || { echo "HATA: mobil KAPSAM_MOB_V1 yok"; exit 1; }
# inkremental guard: V-son zaten var mi? (varsa deploy'a devam ama patch skip eder)
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_ziyaret_etki_server.py  "$SRV" || { rollback; exit 1; }
python3 patch_ziyaret_etki_desktop.py "$DSK" || { rollback; exit 1; }
python3 patch_ziyaret_etki_mobile.py  "$MOB" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm masaüstü"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm mobil"; rollback; exit 1; }
echo "[ok] syntax (server + masaüstü + mobil)"
docker build -t krb-assessment:secure . >/tmp/etki_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/etki_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server  ZIYARET_ETKI_V1:     "; docker exec "$CID" grep -c ZIYARET_ETKI_V1 /app/server.mjs || true
echo -n "[dogrula] masaüstü ZIYARET_ETKI_DK_V1: "; docker exec "$CID" grep -c ZIYARET_ETKI_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil   ZIYARET_ETKI_MOB_V1: "; docker exec "$CID" grep -c ZIYARET_ETKI_MOB_V1 /app/shells/saha.js || true
# --- FINGERPRINT (deploy aninda: build-log + bi_yetenek) ---
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu — elle calistir"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ZIYARET_ETKI_V1',
 'Ziyaret->gelir etkisi (Kohort ROI) raporu canli: ziyaret edilen vs kontrol medyan buyume%, oncesi-ciro dilim-ici karsilastirma (secim yanliligi kontrolu), doz-yanit (ziyaretsiz/1-2/3+). Anchor=veri sonu (donuk ERP feed notrlenir). Manager/admin, masaustu+mobil.',
 'Wave 3 en degerli/en zor rapor; saha ROI kaniti — tek tarafli iddia yerine kontrol grubuyla kiyas, korelasyon dilinde durust cerceve.',
 '{"uc":["/api/saha/rapor/ziyaret-etki"],"markerlar":["ZIYARET_ETKI_V1","ZIYARET_ETKI_DK_V1","ZIYARET_ETKI_MOB_V1"],"tablo":["saha_musteri","saha_ziyaret","bi_satis_faturalari"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ZIYARET_ETKI_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_rapor_ziyaret_etki','rapor',
 'Kohort ROI: ziyaret edilen musteriler, ziyaret edilmeyen (kontrol) benzer musterilere gore ciro olarak daha cok buyudu mu. Oncesi/sonrasi medyan buyume%, oncesi-ciro ceyreklik dilim-ici karsilastirma (secim yanliligi), doz-yanit. Anchor=en son fatura tarihi. Korelasyon; nedensellik iddia etmez.',
 'GET /api/saha/rapor/ziyaret-etki?pencere=90|120|180&tip=TUKETICI|TICARI  (yalniz manager/admin). saha_musteri.musteri_kodu -> bi_satis_faturalari.',
 'saha','canli','taslak',
 '{"uc":["/api/saha/rapor/ziyaret-etki"],"marker":"ZIYARET_ETKI_V1"}'::jsonb,
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_rapor_ziyaret_etki');

-- RETENTION PIVOT (canli veri: kapsam ~%98, kontrol grubu yok -> kohort ROI yerine siklik->tekrar-alim)
UPDATE bi_yetenek SET
  ne_ise_yarar='Ziyaret SIKLIGI -> tekrar-alim (retention): son 12 ayda 0/1-3/4-8/9+ ziyaret gruplarinda, onceki 6 ayda (H1) alan musterinin son 6 ayda (H2) da alma orani. KRB kapsam ~%98 -> kontrol grubu yok, "ziyaret vs ziyaretsiz" yerine siklik-retention (tutara duyarsiz, robust). Ciro buyumesi dagitik oldugundan manset degil. Korelasyon; nedensellik iddia etmez.',
  nasil='GET /api/saha/rapor/ziyaret-etki?tip=TUKETICI|TICARI. REP=kendi defteri (sorumlu_rep scope, az-ornek uyarili) / YONETICI=tum ekip. saha_ziyaret 12-ay sikligi + bi_satis_faturalari H1/H2 tekrar-alim; eslesme musteri_kodu.',
  guncellendi_at=now(), son_gorulme=now()
WHERE ad='saha_rapor_ziyaret_etki';

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ZIYARET_ETKI_V2_RETENTION',
 'Saha ROI raporu kohort-ROI dan RETENTION pivotuna cevrildi: ziyaret sikligi -> tekrar-alim (hic %56 -> sik 9+ %96, monoton). Ihmal cebi: 43 musteri hic ziyaretsiz, ort ciro ~1.5M, tekrar-alim %56.',
 'Canli veri: 731 aktif eslesen musterinin 714u (%98) ziyaret edilmis -> kontrol grubu YOK (ziyaretsiz-alan=11). Kohort ROI de kontrol=11 + medyan/toplam metrik isareti ters -> guvenilmez manset. Durust cozum: kapsam ~tam oldugundan siklik->retention (robust) olctuk; ciro buyumesi birkac dev musteri+duzensiz alimla dagitik oldugundan manset yapilmadi.',
 '{"bulgu":"kapsam %98, kontrol yok","metrik":"tekrar-alim (retention)","gradyan":"56/72/94/96","markerlar":["ZIYARET_ETKI_V1","ZIYARET_ETKI_DK_V1","ZIYARET_ETKI_MOB_V1"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ZIYARET_ETKI_V2_RETENTION');

SELECT 'insa_gunlugu_v1' k, count(*) n FROM bi_insa_gunlugu WHERE adim='ZIYARET_ETKI_V1'
UNION ALL SELECT 'insa_gunlugu_pivot', count(*) FROM bi_insa_gunlugu WHERE adim='ZIYARET_ETKI_V2_RETENTION'
UNION ALL SELECT 'bi_yetenek', count(*) FROM bi_yetenek WHERE ad='saha_rapor_ziyaret_etki';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 📈 Saha ROI (ziyaret sikligi -> tekrar-alim) CANLI — masaüstü+mobil. Yönetici hesabıyla Rapor › 📈 Saha ROI. Hard-refresh / uygulamayı yeniden aç."
