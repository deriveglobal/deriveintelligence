#!/usr/bin/env bash
# TEŞVİK ÇEKMECESİ — bi_tedarikci_tesvik'i atom maliyetine katmadan önce içeriğini oku. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. Kaç satır, hangi markalar/yıllar kapsanıyor"
$PSQL -c "SELECT count(*) satir, count(DISTINCT marka) marka, min(yil) yil_min, max(yil) yil_max FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT marka, yil, segment, kanal FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid ORDER BY marka, yil;" 2>&1 | sed 's/^/  /'

hr "2. Prim yüzdeleri (marka bazında) — hangi kalemler dolu, max_toplam var mı"
$PSQL -x -c "SELECT marka, yil, fatura_alti_pct, donem_primi_pct, sellout_primi_pct, buyume_bonus_pct, kesin_siparis_pct, kanal_operasyon_pct, max_toplam_pct, donem_hedef_min_pct, buyume_hedef_min_pct FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid ORDER BY marka LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "3. Atom markaları ↔ teşvik markaları eşleşiyor mu (isim uyumu)"
$PSQL -c "
WITH am AS (SELECT DISTINCT upper(marka) m FROM bi_marj_atom WHERE tenant_id='$T'::uuid),
     tm AS (SELECT DISTINCT upper(marka) m FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid)
SELECT (SELECT count(*) FROM am) atom_marka, (SELECT count(*) FROM tm) tesvik_marka,
       (SELECT count(*) FROM am JOIN tm USING(m)) eslesen;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT DISTINCT upper(marka) tesvik_marka FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "4. Toplam efektif prim (kaba): hangi marka ne kadar maliyet indirimi görür"
$PSQL -c "SELECT marka, yil,
   COALESCE(max_toplam_pct, COALESCE(fatura_alti_pct,0)+COALESCE(donem_primi_pct,0)+COALESCE(sellout_primi_pct,0)+COALESCE(buyume_bonus_pct,0)+COALESCE(kesin_siparis_pct,0)+COALESCE(kanal_operasyon_pct,0)) AS kaba_toplam_pct
 FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid ORDER BY kaba_toplam_pct DESC NULLS LAST LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "BITTI — teşvik yapısı görülünce net-maliyet formülünü (koşulları dürüstçe) kurarım."
