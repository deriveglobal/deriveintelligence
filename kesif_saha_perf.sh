#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
S=/opt/krb-assessment/server_container.mjs
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. MEVCUT INDEXLER (hot tablolar)"
$PSQL -c "SELECT tablename, indexname, indexdef FROM pg_indexes WHERE tablename IN ('saha_ziyaret','saha_ziyaret_foto','saha_teklif','saha_musteri','master_musteri','saha_oneri','saha_oneri_mesaj') ORDER BY tablename, indexname;"

hr "2. SATIR SAYILARI"
$PSQL -c "SELECT 'saha_ziyaret' t,count(*) n FROM saha_ziyaret UNION ALL SELECT 'saha_ziyaret_foto',count(*) FROM saha_ziyaret_foto UNION ALL SELECT 'saha_teklif',count(*) FROM saha_teklif UNION ALL SELECT 'saha_musteri',count(*) FROM saha_musteri UNION ALL SELECT 'master_musteri',count(*) FROM master_musteri UNION ALL SELECT 'saha_oneri',count(*) FROM saha_oneri;"

hr "3. EXPLAIN — musteri listesi son_ziyaret LATERAL (rep filtresiz ornek)"
$PSQL -c "EXPLAIN (ANALYZE, BUFFERS, TIMING) SELECT m.id, (SELECT MAX(z.ziyaret_tarihi) FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.durum='TAMAMLANDI') FROM saha_musteri m WHERE m.aktif=true LIMIT 50;" 2>&1 | head -25

hr "4. EXPLAIN — master_musteri join (kodla)"
$PSQL -c "EXPLAIN (ANALYZE, BUFFERS) SELECT m.id, mm.toplam_ciro FROM saha_musteri m LEFT JOIN master_musteri mm ON mm.tenant_id=m.tenant_id AND mm.musteri_kodu=m.musteri_kodu WHERE m.aktif=true LIMIT 50;" 2>&1 | head -20

hr "5. /api/saha/oneriler endpoint (neden 20s)"
grep -nE "path === \"/api/saha/oneriler\"" "$S"
