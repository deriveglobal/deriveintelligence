#!/usr/bin/env bash
# MUSTERI_ATAMA_FIX_V1 — Müşteri Atama paneli tasarım-sistemi uyumu (yalnız konsol).
#   Inline <style> + elle hex kaldırıldı → stiller taStyles() kanonik sheet'e; markup ta-* sınıflarına.
#   Sunucu/DDL DEĞİŞMEZ. Rollback'li, tek build. Fingerprint: bi_insa_gunlugu build-log.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_musteri_atama_fix.sh patch_musteri_atama_fix.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_atama_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
CON=shells/tenant-admin.js
[ -f "$CON" ] || { echo "HATA: $CON yok"; exit 1; }
[ -f patch_musteri_atama_fix.py ] || { echo "HATA: patch_musteri_atama_fix.py yok"; exit 1; }
grep -q "MUSTERI_ATAMA_V1" "$CON" || { echo "HATA: önce MUSTERI_ATAMA_V1 canlı olmalı"; exit 1; }
TS=$(date +%s)
cp -a "$CON" "$CON.bak.$TS"; echo "[yedek] $CON.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$CON.bak.$TS" "$CON"; }
python3 patch_musteri_atama_fix.py "$CON" || { rollback; exit 1; }
node --check "$CON" || { echo "HATA konsol node"; rollback; exit 1; }
cp "$CON" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm konsol"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/atafix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/atafix_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] FIX_V1: ";   docker exec "$CID" grep -c MUSTERI_ATAMA_FIX_V1   /app/shells/tenant-admin.js || true
echo -n "[dogrula] STYLE_V1: "; docker exec "$CID" grep -c MUSTERI_ATAMA_STYLE_V1 /app/shells/tenant-admin.js || true
echo -n "[dogrula] inline <style> (0 olmalı): "; docker exec "$CID" sh -c "grep -c 'content.innerHTML = \`<style>' /app/shells/tenant-admin.js || true"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_ATAMA_FIX_V1',
 'Musteri Atama paneli tasarim-sistemi uyumu: render icindeki inline <style> blogu + elle hex KALDIRILDI; panel stilleri taStyles() kanonik stylesheet''e tasindi (marker MUSTERI_ATAMA_STYLE_V1, renkler mevcut paletten); markup mevcut ta-* siniflarina cevrildi (ta-fil/ta-ataact/ta-atawarn/ta-atarep/ta-atagec/ta-atabar/ta-atastat). Islem butonu flex-td sarma bitti; gorsel bozukluk (sag bosluk) giderildi.',
 'Kural: sistemde dogrudan gomulu (inline) stil/hex olmaz — tek kanonik stylesheet + mevcut tasarim sinifi. V1 render bloguna inline <style> sizmisti.',
 '{"marker":"MUSTERI_ATAMA_FIX_V1","stil_marker":"MUSTERI_ATAMA_STYLE_V1","surface":"tenant-admin > Müşteri Atama","kapsam":"yalniz konsol; server/DDL degismedi"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_ATAMA_FIX_V1');
SELECT 'insa_gunlugu' k, count(*) n FROM bi_insa_gunlugu WHERE adim='MUSTERI_ATAMA_FIX_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_ATAMA_FIX_V1 CANLI — Yönetim › Müşteriler › Atama. Hard-refresh (Cmd+Shift+R)."
