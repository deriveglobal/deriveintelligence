#!/usr/bin/env bash
# OMURGA 45 — sebep_arastir_marj v2: ATOMDAN + gerçek köprü (fiyat+maliyet+mix TL). DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. sebep_arastir_marj v2 (atom + köprü)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_marj(p_tenant uuid, p_marka text) RETURNS jsonb AS $fn$
DECLARE m0 date := date_trunc('month',CURRENT_DATE)::date;
  ciro_o numeric; ciro_s numeric; marjo_m numeric; marjs_m numeric; marjo_p numeric; marjs_p numeric;
  fiyat_et numeric; maliyet_et numeric; degisim numeric; mix_et numeric;
  baskin text; sebep text; aksiyon text; guv text;
BEGIN
  WITH a AS (
    SELECT kalem_kodu,
      sum(ciro)         FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') co,
      sum(adet)         FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') qo,
      sum(ciro-brut_kar)FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') smmo,
      sum(ciro)         FILTER (WHERE ay>=m0-interval '6 month'  AND ay<m0) cs,
      sum(adet)         FILTER (WHERE ay>=m0-interval '6 month'  AND ay<m0) qs,
      sum(ciro-brut_kar)FILTER (WHERE ay>=m0-interval '6 month'  AND ay<m0) smms
    FROM bi_marj_atom WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka) AND ay>=m0-interval '12 month'
    GROUP BY kalem_kodu)
  SELECT round(sum(co)/1e6,1), round(sum(cs)/1e6,1),
         round(sum(co-smmo)/1e6,2), round(sum(cs-smms)/1e6,2),
         round(100*sum(co-smmo)/nullif(sum(co),0),1), round(100*sum(cs-smms)/nullif(sum(cs),0),1),
         round(sum(CASE WHEN qo>0 AND qs>0 THEN qs*((cs/qs)-(co/qo)) END)/1e6,2),
         round(sum(CASE WHEN qo>0 AND qs>0 THEN qs*((smmo/qo)-(smms/qs)) END)/1e6,2)
    INTO ciro_o, ciro_s, marjo_m, marjs_m, marjo_p, marjs_p, fiyat_et, maliyet_et
    FROM a;

  degisim := round(marjs_m - marjo_m, 2);
  mix_et  := round(degisim - fiyat_et - maliyet_et, 2);

  IF marjs_p >= marjo_p THEN
    sebep := 'Marj oranı düşmedi (%'||marjo_p||'→%'||marjs_p||').'; aksiyon := 'Aksiyon yok.'; guv:='kesin';
  ELSE
    -- en baskın NEGATİF kaldıraç
    baskin := CASE
      WHEN maliyet_et<=fiyat_et AND maliyet_et<=mix_et THEN 'maliyet artışı (enflasyon)'
      WHEN mix_et<=fiyat_et AND mix_et<=maliyet_et THEN 'mix (ucuz-marjlı ürüne kayış)'
      ELSE 'fiyat' END;
    sebep := 'Marj oranı %'||marjo_p||'→%'||marjs_p||' düştü. KÖPRÜ (TL): maliyet '||maliyet_et||'M · mix '||mix_et||'M · fiyat '||fiyat_et||'M. Baskın: '||baskin||'.';
    aksiyon := CASE
      WHEN baskin LIKE 'maliyet%' THEN 'Maliyet fiyatı geçti — maliyet-artan SKU''larda daha sert zam / tedarikçi primi / daha iyi alış.'
      WHEN baskin LIKE 'mix%' THEN 'Fiyat değil mix — yüksek-marjlı ürün/segmente yüklen ya da ucuz-marj hacmi stratejik mi karar ver.'
      ELSE 'Ortalama fiyat düştü — fiyat/iskonto disiplinini gözden geçir.' END;
    guv:='kesin';
  END IF;

  RETURN jsonb_build_object('marka',upper(p_marka),'ciro_o_m',ciro_o,'ciro_s_m',ciro_s,
    'marj_pct_o',marjo_p,'marj_pct_s',marjs_p,'sebep',sebep,'aksiyon',aksiyon,'guven',guv,
    'kopru',jsonb_build_object('degisim_m',degisim,'fiyat_m',fiyat_et,'maliyet_m',maliyet_et,'mix_m',mix_et),
    'kaynak','bi_marj_atom (dönem-eşleşmeli)',
    'kontrol_edilemedi',jsonb_build_array('tedarikçi primi (bi_tedarikci_tesvik henüz maliyete katılmadı)','piyasa/ziyaret markaya-özgü eşleme'));
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ sebep_arastir_marj v2 (atom+köprü)"

hr "2. TEST — CONTINENTAL (köprü: maliyet≈−3,3 · mix≈−3,0 · fiyat≈+2,4 çıkmalı)"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_marj('$T'::uuid,'CONTINENTAL'));" 2>&1 | sed 's/^/  /'

hr "3. GENELLEŞME — LASSA + HERKUL sebep"
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'LASSA'))->>'sebep' lassa;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'HERKUL'))->>'sebep' herkul;" 2>&1 | sed 's/^/  /'

hr "BITTI — sebep-araştırıcı atomdan + gerçek köprü. Sonra içgörü motorunu atoma+buna bağla."
