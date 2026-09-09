#!/usr/bin/env bash
# OMURGA 35 — sebep_arastir_marj(tenant,marka): bataryayı fonksiyona sar, jsonb kanıt+verdict. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. FONKSİYON — sebep_arastir_marj (mix + fiyat + iade; ziyaret/piyasa dürüst-boşluk)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_marj(p_tenant uuid, p_marka text) RETURNS jsonb AS $fn$
DECLARE m0 date := date_trunc('month',CURRENT_DATE)::date;
  marj_o numeric; marj_s numeric; ciro_o numeric; ciro_s numeric;
  d_o numeric; d_s numeric; y_o numeric; y_s numeric;  -- düşük/yüksek marj ciro
  fiyat_o numeric; fiyat_s numeric; iade_o numeric; iade_s numeric;
  mix_kayma numeric; sebep text; aksiyon text; guv text;
BEGIN
  WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) bm FROM bi_stok_hareket WHERE tenant_id=p_tenant AND giris>0 GROUP BY kalem_kodu),
  c AS (SELECT s.kalem_kodu, max(km.bm) cost,
      sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0-interval '6 month') co,
      sum(s.miktar)      FILTER (WHERE s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0-interval '6 month') qo,
      sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=m0-interval '6 month' AND s.fatura_tarihi<m0) cs,
      sum(s.miktar)      FILTER (WHERE s.fatura_tarihi>=m0-interval '6 month' AND s.fatura_tarihi<m0) qs
    FROM bi_satis_faturalari s JOIN km ON km.kalem_kodu=s.kalem_kodu
    WHERE s.tenant_id::text=p_tenant::text AND upper(s.marka)=upper(p_marka) AND s.ebat IS NOT NULL AND s.miktar>0
      AND s.fatura_tarihi>=m0-interval '12 month' GROUP BY s.kalem_kodu)
  SELECT round(sum(co)/1e6,1), round(100*(sum(co)-sum(qo*cost))/nullif(sum(co),0),1),
         round(sum(cs)/1e6,1), round(100*(sum(cs)-sum(qs*cost))/nullif(sum(cs),0),1),
         round(sum(co) FILTER (WHERE cs>0 AND (1-cost/nullif(cs/nullif(qs,0),0))<0.20)/1e6,1),
         round(sum(cs) FILTER (WHERE cs>0 AND (1-cost/nullif(cs/nullif(qs,0),0))<0.20)/1e6,1),
         round(sum(co) FILTER (WHERE cs>0 AND (1-cost/nullif(cs/nullif(qs,0),0))>=0.20)/1e6,1),
         round(sum(cs) FILTER (WHERE cs>0 AND (1-cost/nullif(cs/nullif(qs,0),0))>=0.20)/1e6,1),
         round(sum(co)/nullif(sum(qo),0)), round(sum(cs)/nullif(sum(qs),0))
    INTO ciro_o, marj_o, ciro_s, marj_s, d_o, d_s, y_o, y_s, fiyat_o, fiyat_s FROM c;

  SELECT round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '12 month' AND fatura_tarihi<m0-interval '6 month')/1e6,2),
         round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '6 month')/1e6,2)
    INTO iade_o, iade_s FROM bi_satis_faturalari
   WHERE tenant_id::text=p_tenant::text AND upper(marka)=upper(p_marka) AND miktar<0;

  mix_kayma := round( 100*(COALESCE(d_s,0)/nullif(COALESCE(d_s,0)+COALESCE(y_s,0),0)) - 100*(COALESCE(d_o,0)/nullif(COALESCE(d_o,0)+COALESCE(y_o,0),0)), 0);

  IF marj_s >= marj_o THEN
    sebep := 'marj düşmedi'; aksiyon := 'aksiyon yok'; guv:='kesin';
  ELSIF mix_kayma >= 15 THEN
    sebep := 'MIX kayması — büyüme düşük-marjlı ürünlere kaydı (düşük-marj ciro '||d_o||'→'||d_s||'M). Fiyatlar düşmedi ('||fiyat_o||'→'||fiyat_s||').';
    aksiyon := 'Fiyat değil — mix sorunu. Yüksek-marjlı ürün/segmente yüklen ya da düşük-marj hacmi stratejik mi karar ver.'; guv:='kesin';
  ELSIF fiyat_s < fiyat_o*0.97 THEN
    sebep := 'FİYAT — ortalama satış fiyatı düştü ('||fiyat_o||'→'||fiyat_s||'). Mix değil.';
    aksiyon := 'Fiyat/iskonto disiplinini gözden geçir. Neden düştü — piyasa? teklif kırma? (piyasa çekmecesi ebat-eşleme ister).'; guv:='kesin';
  ELSE
    sebep := 'BELİRSİZ — mix ('||mix_kayma||' puan) ve fiyat ('||fiyat_o||'→'||fiyat_s||') tek başına açıklamıyor.';
    aksiyon := 'İnsan incelemesi — çekmeceler net sebep vermedi.'; guv:='dusuk';
  END IF;

  RETURN jsonb_build_object(
    'marka', upper(p_marka), 'marj_o', marj_o, 'marj_s', marj_s, 'ciro_o', ciro_o, 'ciro_s', ciro_s,
    'sebep', sebep, 'aksiyon', aksiyon, 'guven', guv,
    'kanit', jsonb_build_object(
       'mix', jsonb_build_object('dusuk_marj_ciro_o',d_o,'dusuk_marj_ciro_s',d_s,'yuksek_marj_ciro_o',y_o,'yuksek_marj_ciro_s',y_s,'dusuk_pay_kayma_puan',mix_kayma),
       'fiyat', jsonb_build_object('ort_fiyat_o',fiyat_o,'ort_fiyat_s',fiyat_s),
       'iade', jsonb_build_object('onceki_m',iade_o,'son_m',iade_s)),
    'kontrol_edilemedi', jsonb_build_array('piyasa (ebat-eşleme + tarih derinliği gerekiyor)', 'ziyaret (markaya-özgü sinyal eşlemesi gerekiyor)'));
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ sebep_arastir_marj"

hr "2. TEST — CONTINENTAL (mix çıkmalı)"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_marj('$T'::uuid,'CONTINENTAL'));" 2>&1 | sed 's/^/  /'

hr "3. GENELLEŞME — LASSA + BRIDGESTONE (farklı marka, farklı sebep mi)"
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'LASSA'))->>'sebep' AS lassa_sebep;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'BRIDGESTONE'))->>'sebep' AS brs_sebep;" 2>&1 | sed 's/^/  /'

hr "BITTI — araştırıcı fonksiyon çalışıyor + genelleşiyor mu?"
