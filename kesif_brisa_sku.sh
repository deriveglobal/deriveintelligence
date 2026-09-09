#!/usr/bin/env bash
# TEK SKU — Brisa'nın faturaladığı gerçek maliyet vs retail liste vs KRB satış. READ-ONLY.
# Örnek: LASSA 205/55R16 (atom kalem_kodu 214992-25). Beklenti: %35 fatura-altı → maliyet ≈ liste×0,65.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. bi_tedarikci_faturalari kolonları (Brisa alış faturası — gerçek maliyet)"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_tedarikci_faturalari';" 2>&1 | sed 's/^/  /'

hr "1. BRISA ALIŞ FATURALARI — LASSA 205/55R16 (kalem_kodu 214992*) : tarih·kod·birim maliyet·adet"
$PSQL -c "SELECT fatura_tarihi, kalem_kodu, marka, ebat, round(birim_fiyat_kdv_haric) brisa_birim_maliyet, miktar
  FROM bi_tedarikci_faturalari
  WHERE tenant_id::text='$T' AND (kalem_kodu LIKE '214992%' OR (marka ILIKE '%LASSA%' AND ebat='205/55R16'))
  ORDER BY fatura_tarihi DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "2. KRB SATIŞ — aynı SKU (kalem_kodu 214992*) son satışlar : tarih·birim satış"
$PSQL -c "SELECT fatura_tarihi, kalem_kodu, marka, ebat, round(satir_tutar/nullif(miktar,0)) krb_birim_satis, miktar
  FROM bi_satis_faturalari
  WHERE tenant_id::text='$T' AND miktar>0 AND (kalem_kodu LIKE '214992%' OR (marka ILIKE '%LASSA%' AND ebat='205/55R16'))
  ORDER BY fatura_tarihi DESC LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "3. ÖZET — retail liste 6.087 (SNOWAYS 5). %35 off = 4.087×... referans"
$PSQL -c "SELECT 6087 AS retail_liste, round(6087*0.65) AS liste_eksi_35, round(6087*0.65*0.65) AS liste_eksi_35_iki_kez;" 2>&1 | sed 's/^/  /'

hr "BITTI — Brisa birim maliyeti (blok 1) liste 6.087'nin yüzde kaçı? %65 (tek 35) mi, %44 mi (daha fazla iskonto)?"
