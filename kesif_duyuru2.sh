#!/usr/bin/env bash
# DUYURU yeniden keşif — doğru kolonlar (baslik/icerik/tip). OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. saha_duyuru — tip dağılımı + toplam"
$PSQL -c "SELECT tip, count(*) FROM saha_duyuru WHERE tenant_id='$T'::uuid GROUP BY tip;" 2>&1 | sed 's/^/  /'

hr "2. son 10 duyuru (tip · başlık · içerik ilk 90)"
$PSQL -c "SELECT to_char(created_at,'MM-DD') t, tip, left(coalesce(baslik,'')||' — '||coalesce(icerik,''),90) FROM saha_duyuru WHERE tenant_id='$T'::uuid ORDER BY created_at DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "3. marka/fiyat/zam/rakip geçen duyurular"
$PSQL -c "SELECT to_char(created_at,'MM-DD') t, tip, left(coalesce(baslik,'')||' '||coalesce(icerik,''),130)
  FROM saha_duyuru WHERE tenant_id='$T'::uuid
   AND coalesce(baslik,'')||' '||coalesce(icerik,'') ~* '(continental|lassa|herkul|petlas|matador|zam|fiyat|indirim|rakip|kampanya|maliyet|stok)'
  ORDER BY created_at DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "4. saha_sinyal — piyasa/rakip/fiyat geçen (ödeme dışı istihbarat)"
$PSQL -c "SELECT to_char(created_at,'MM-DD') t, tip, left(coalesce(ozet,ham_metin,''),110)
  FROM saha_sinyal WHERE tenant_id='$T'::uuid
   AND coalesce(ozet,'')||' '||coalesce(ham_metin,'') ~* '(continental|lassa|herkul|petlas|matador|zam|fiyat|indirim|rakip|kampanya|205/55|315/70)'
  ORDER BY created_at DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "BITTI"
