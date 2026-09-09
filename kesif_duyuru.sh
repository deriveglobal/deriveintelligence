#!/usr/bin/env bash
# DUYURU + SAHA-METİN çekmeceleri keşif — marj sebebi topraklayacak insan-bilgisi var mı. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. saha_duyuru — kolonlar + tür dağılımı + satır"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='saha_duyuru';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT tur, count(*) FROM saha_duyuru WHERE tenant_id='$T'::uuid GROUP BY tur;" 2>&1 | sed 's/^/  /'

hr "2. saha_duyuru — son 8 kayıt (tür + metin ilk 100)"
$PSQL -c "SELECT to_char(created_at,'MM-DD') t, tur, left(coalesce(baslik,'')||' — '||coalesce(icerik,metin,''),100) FROM saha_duyuru WHERE tenant_id='$T'::uuid ORDER BY created_at DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "3. Marka geçen duyuru var mı (CONTINENTAL/LASSA/HERKUL/PETLAS + fiyat/zam/rakip)"
$PSQL -c "SELECT to_char(created_at,'MM-DD') t, tur, left(coalesce(baslik,'')||' '||coalesce(icerik,metin,''),120)
  FROM saha_duyuru WHERE tenant_id='$T'::uuid
   AND coalesce(baslik,'')||' '||coalesce(icerik,metin,'') ~* '(continental|lassa|herkul|petlas|zam|fiyat|indirim|rakip|kampanya|maliyet)'
  ORDER BY created_at DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "4. saha_sinyal — özet metin (piyasa istihbaratı) son 6"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='saha_sinyal';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT left(coalesce(ozet,ham_metin,''),110) FROM saha_sinyal WHERE tenant_id='$T'::uuid ORDER BY created_at DESC NULLS LAST LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "5. saha_rakip_teklif — sahadan gerçek rakip fiyat (marka bazlı adet)"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='saha_rakip_teklif';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT count(*) FROM saha_rakip_teklif WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "BITTI — duyuru/sinyal/rakip-teklif metinlerinde topraklanabilir sebep var mı, ona göre bağlarım."
