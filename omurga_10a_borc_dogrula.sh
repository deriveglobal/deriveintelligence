#!/usr/bin/env bash
# BORÇ DOĞRULA — bi_cari_bakiye kolonları + bugünkü borç ~403M + Brisa yoğunlaşması. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_cari_bakiye — kolonlar (tedarikci_bakiye, musteri_bakiye, net_pozisyon, tenant_id tipi)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_cari_bakiye' ORDER BY ordinal_position;"

hr "2. BUGÜNKÜ BORÇ — SUM(ABS(tedarikci_bakiye<0)) ~403M + net pozisyon + adet"
$PSQL -c "
SELECT round(sum(abs(tedarikci_bakiye)) FILTER (WHERE tedarikci_bakiye<0)/1e6,1) borc_m,
       count(*) FILTER (WHERE tedarikci_bakiye<0) borclu_tedarikci,
       round(sum(tedarikci_bakiye)/1e6,1) net_tedarikci_m
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;"
echo "  ⚠ ~403M (113 tedarikçi) bekleniyor (Sözleşme METRİK 2)."

hr "3. YOĞUNLAŞMA — en büyük borçlu tedarikçiler (Brisa ~%79 mu? bu bir DURUM)"
$PSQL -c "
WITH b AS (SELECT muhatap_adi, abs(tedarikci_bakiye) borc FROM bi_cari_bakiye
            WHERE tenant_id='$T'::uuid AND tedarikci_bakiye<0)
SELECT left(muhatap_adi,32) tedarikci, round(borc/1e6,1) borc_m,
       round(100.0*borc/sum(borc) OVER (),1) pay_pct
  FROM b ORDER BY borc DESC LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "4. İÇ TUTARLILIK — net_pozisyon = musteri + tedarikci (Sözleşme: fark 0)"
$PSQL -c "SELECT round((sum(net_pozisyon)-sum(musteri_bakiye)-sum(tedarikci_bakiye))) fark
          FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ fark 0 olmalı (ERP aritmetiği). net_pozisyon kolonu yoksa hata çıkar."

hr "BITTI — borç snapshot-only: doğrulanınca cron'a eklenir (geçmiş YOK, bugünden biriktir)."
