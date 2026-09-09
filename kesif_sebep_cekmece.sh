#!/usr/bin/env bash
# SEBEP ÇEKMECELERİ KEŞİF — maliyet/fiyat baskınını topraklayacak çekmecelerde VERİ var mı. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_tedarikci_tesvik — maliyet çekmecesi (veri var mı, kolonlar)"
$PSQL -c "SELECT count(*) satir FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_tedarikci_tesvik';" 2>&1 | sed 's/^/  /'

hr "2. bi_tedarikci_kampanya — maliyet çekmecesi 2"
$PSQL -c "SELECT count(*) satir FROM bi_tedarikci_kampanya WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "3. bi_ekonomik_parametreler — döviz/enflasyon çekmecesi (son 12 ay USD var mı)"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_ekonomik_parametreler';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT count(*) FROM bi_ekonomik_parametreler;" 2>&1 | sed 's/^/  /'

hr "4. saha_iskonto_talep — fiyat/iskonto çekmecesi (onaylı iskonto var mı)"
$PSQL -c "SELECT count(*) satir FROM saha_iskonto_talep WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='saha_iskonto_talep';" 2>&1 | sed 's/^/  /'

hr "5. bi_rakip_fiyat — piyasa çekmecesi (CONTINENTAL rakip fiyat var mı)"
$PSQL -c "SELECT count(*) FILTER (WHERE marka ILIKE '%CONTINENTAL%') continental, count(*) toplam FROM bi_rakip_fiyat WHERE tenant_id='$T'::text;" 2>&1 | sed 's/^/  /'

hr "6. MİX topraklama testi — CONTINENTAL: payı en çok artan düşük-marjlı SKU'lar (atomdan)"
$PSQL -c "
WITH a AS (SELECT kalem_kodu, max(ebat) ebat,
  sum(adet) FILTER (WHERE ay>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND ay<date_trunc('month',CURRENT_DATE)-interval '6 month') qo,
  sum(adet) FILTER (WHERE ay>=date_trunc('month',CURRENT_DATE)-interval '6 month') qs,
  round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj
  FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)='CONTINENTAL' GROUP BY kalem_kodu)
SELECT ebat, qo, qs, marj FROM a WHERE qs>qo ORDER BY (qs-COALESCE(qo,0)) DESC LIMIT 5;" 2>&1 | sed 's/^/  /'

hr "BITTI — hangi çekmece dolu, hangisi boş. Buna göre v3 topraklar ya da dürüstçe sorar."
