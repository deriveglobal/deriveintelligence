#!/usr/bin/env bash
# ERP INGEST TEŞHİSİ — neden donmuş + donma tarihini KESİNLEŞTİR. READ-ONLY (hiçbir şey değişmez).
# Amaç (DEVIR §6.2 / TESPIT §7): ingest ölü mü, hangi mekanizma vardı, #100 invmoving24 / #101 5MB / #102 SAP B1 nedir,
#   ve son gerçek veri tarihi tam olarak ne. Çatal (onar vs snapshot'ta devam) bunun sonucuyla verilecek.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
REPO='/opt/krb-assessment'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. DONMA TARİHİ — canlı ERP tablolarında SON tarih (TESPIT §7: ~07-13 hipotezini kesinleştir)"
$PSQL -c "SELECT 'satis'  AS kaynak, max(fatura_tarihi)::date son_tarih, count(*) satir FROM bi_satis_faturalari    WHERE tenant_id::text='$T'
UNION ALL SELECT 'tedarikci', max(fatura_tarihi)::date, count(*)               FROM bi_tedarikci_faturalari WHERE tenant_id::text='$T';" 2>&1 | sed 's/^/  /'

hr "1b. SATIŞ — son 20 günün günlük satır sayısı (kuyruk nerede kesiliyor görülsün)"
$PSQL -c "SELECT fatura_tarihi::date gun, count(*) satir FROM bi_satis_faturalari
  WHERE tenant_id::text='$T' AND fatura_tarihi > (CURRENT_DATE - 45)
  GROUP BY 1 ORDER BY 1 DESC LIMIT 20;" 2>&1 | sed 's/^/  /'

hr "2. STOK HAREKET — kolonları (tarih alanı adını görüp doğru sorgulayalım, VARSAYMADAN)"
$PSQL -c "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_stok_hareket';" 2>&1 | sed 's/^/  /'

hr "3. INGEST HEDEF TABLOLARI — ERP ham veri tablolarının listesi (satis/tedarikci/stok/fatura/hareket + yedekler)"
$PSQL -c "SELECT relname, to_char(n_live_tup,'999G999G999') AS satir, pg_size_pretty(pg_total_relation_size(relid)) AS boyut
  FROM pg_stat_user_tables
  WHERE relname ~ '(satis|tedarikci|stok|fatura|hareket|invmov|yukle|ingest|import)'
  ORDER BY pg_total_relation_size(relid) DESC LIMIT 40;" 2>&1 | sed 's/^/  /'

hr "4. YÜKLEME/LOG İZİ — bir yükleme kaydı tablosu var mı (son ingest ne zaman/nasıl oldu)"
$PSQL -c "SELECT table_name FROM information_schema.tables
  WHERE table_schema='public' AND table_name ~ '(yukle|ingest|import|log|load|aktar)' ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "5. #100 invmoving24 — böyle bir tablo/view VAR MI? (tam + benzer isim)"
$PSQL -c "SELECT table_name, table_type FROM information_schema.tables
  WHERE table_schema='public' AND table_name ILIKE '%invmov%' ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "6. INGEST CRON'U VAR MI? — host crontab (iddia: ingest cron YOK; metrik 08:15 + nabız 08:35 + scraper var)"
crontab -l 2>&1 | grep -vE '^\s*#' | sed 's/^/  /'

hr "7. KODDA INGEST İZİ — #101 5MB limiti + upload/ingest/invmoving endpoint'leri (server_container.mjs)"
grep -nE '(5 ?\* ?1024|5242880|5MB|5 ?MB|maxFileSize|limit.*[0-9]{6,}|upload|ingest|invmoving|/api/.*(yukle|import|aktar))' \
  "$REPO/server_container.mjs" 2>&1 | head -30 | sed 's/^/  /'

hr "8. INGEST/SAP SCRIPT İZİ — repo'da SAP B1 pull (#102) ya da yükleme scripti var mı"
ls -1 "$REPO"/*.sh "$REPO"/shells/*.js 2>/dev/null | grep -iE '(sap|ingest|yukle|import|aktar|invmov|pull|erp)' | sed 's/^/  /'
grep -rilE '(sap.?b1|service.?layer|sap business one|invmoving24)' "$REPO" --include='*.sh' --include='*.js' --include='*.mjs' 2>/dev/null | head -10 | sed 's/^/  /'

hr "9. DİSK — taze yükleme için yer var mı (766MB ölü yedek biliniyor; %59 doluydu)"
df -h / 2>&1 | sed 's/^/  /'

hr "BITTI — KİLİT SORULAR: (a) kesin donma tarihi = blok 1 son_tarih. (b) ingest ölü çünkü: hiç ingest cron'u yok mu (blok 6) / endpoint var ama tetiklenmiyor mu (blok 7) / SAP B1 pull kırık mı (blok 8)? (c) invmoving24 (#100) canlı bir nesne mi yoksa sadece kodda geçen bir ad mı (blok 5/7)? → Sonuç gelince: ONAR vs SNAPSHOT'ta devam çatalını birlikte kararlaştıracağız."
