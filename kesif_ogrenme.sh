#!/usr/bin/env bash
# ÖĞRENME ALTYAPISI KEŞİF — bi_soru_uret + bi_sistem_sorusu + var olan sor/cevapla yolu. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_soru_uret fonksiyon gövdesi (ne üretiyor)"
$PSQL -c "SELECT pg_get_functiondef('bi_soru_uret'::regproc);" 2>&1 | sed 's/^/  /'

hr "2. bi_sistem_sorusu — durum dağılımı + son 3 kayıt"
$PSQL -c "SELECT durum, count(*) FROM bi_sistem_sorusu GROUP BY durum;" 2>&1 | sed 's/^/  /'
$PSQL -x -c "SELECT anahtar, left(soru,80) soru, secenekler, cevap, durum FROM bi_sistem_sorusu ORDER BY olusma DESC LIMIT 3;" 2>&1 | head -30 | sed 's/^/  /'

hr "3. ENDPOINT — sistem sorusu sor/cevapla var mı (server'da)"
grep -noE "sistem_sorusu|sistem-soru|bi_soru_uret|/api/[a-z/-]*soru[a-z/-]*" server_container.mjs | head -20 | sed 's/^/  /'

hr "4. bi_sinyal.geri_donus_sebebi + karar_gerekce — zaten 'neden' öğreniyor mu"
$PSQL -c "SELECT count(*) FILTER (WHERE geri_donus_sebebi IS NOT NULL) geri_donus_dolu, count(*) FILTER (WHERE karar_gerekce IS NOT NULL) gerekce_dolu, count(*) toplam FROM bi_sinyal WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "5. bi_soru_uret çağrılıyor mu (server/cron)"
grep -rn "bi_soru_uret\|sistem_sorusu" server_container.mjs *.sh 2>/dev/null | head -10 | sed 's/^/  /'

hr "BITTI — mevcut sor/cevapla neyi kapsıyor; eksik halkayı ona göre bağlarım."
