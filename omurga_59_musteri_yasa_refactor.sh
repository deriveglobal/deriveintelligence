#!/usr/bin/env bash
# OMURGA 59 — YAMAYI ÇIKAR: sebep_arastir_musteri artık net/sanity'yi GÖMMÜYOR, capraz_kontrol'ü çağırıyor.
# Üretici sadece DOMAIN gerçeklerini (ciro trendi, ödeme hızı) tutar; kesişen yasalar runner'dan gelir.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. sebep_arastir_musteri — İNCE (yasalar runner'dan)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_musteri(p_tenant uuid, p_kod text) RETURNS jsonb AS $fn$
DECLARE
  m0 date := date_trunc('month',CURRENT_DATE)::date;
  ad text; rep text; vade text; vgecmis numeric; limit_k numeric;
  tahsil_gun numeric; ciro_s numeric; ciro_o numeric;
  bulgular text[] := '{}'; guv text := 'yaklasik'; oneri text;
  yasa_out jsonb; f jsonb; kodlar text[] := '{}';
BEGIN
  SELECT muhatap_adi, satis_calisani, odeme_kosulu, vadesi_gecmis, kredi_limiti
    INTO ad, rep, vade, vgecmis, limit_k
    FROM bi_musteri_risk WHERE tenant_id=p_tenant AND muhatap_kodu=p_kod;
  IF ad IS NULL THEN SELECT max(musteri_adi) INTO ad FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND musteri_kodu=p_kod; END IF;
  SELECT ort_tahsilat_gun INTO tahsil_gun FROM bi_musteri_risk_odeme WHERE tenant_id=p_tenant AND muhatap_kodu=p_kod LIMIT 1;
  SELECT sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '6 month' AND fatura_tarihi<m0),
         sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '12 month' AND fatura_tarihi<m0-interval '6 month')
    INTO ciro_s, ciro_o
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND musteri_kodu=p_kod AND fatura_tarihi>=m0-interval '12 month';
  ciro_s:=COALESCE(ciro_s,0); ciro_o:=COALESCE(ciro_o,0);

  -- ── DOMAIN gerçekleri (yalnızca müşteriye özgü davranış) ──
  IF ciro_o>0 AND ciro_s=0 THEN
    bulgular := bulgular || (ad||' son 6 ayda hiç alım yapmadı; önceki 6 ayda '||_mln(ciro_o)||' milyon TL almıştı — sessiz kayıp riski');
  ELSIF ciro_o>0 AND ciro_s < ciro_o*0.7 THEN
    bulgular := bulgular || (ad||' cirosu son 6 ayda '||_mln(ciro_o)||' milyon TL''den '||_mln(ciro_s)||' milyon TL''ye düştü (%'||round(100*(ciro_s-ciro_o)/ciro_o)||')');
  ELSIF ciro_o>0 AND ciro_s > ciro_o*1.5 THEN
    bulgular := bulgular || (ad||' cirosu son 6 ayda '||_mln(ciro_o)||'M''den '||_mln(ciro_s)||'M''ye büyüdü (%'||round(100*(ciro_s-ciro_o)/ciro_o)||') — fırsat');
  END IF;

  -- ── KESİŞEN YASALAR (runner; net_pozisyon, veri_makul, ...) ──
  yasa_out := capraz_kontrol(p_tenant,'musteri',p_kod);
  FOR f IN SELECT jsonb_array_elements(yasa_out) LOOP
    bulgular := bulgular || (f->>'bulgu');
    kodlar := kodlar || (f->>'yasa');
  END LOOP;

  -- ── Hiçbir yasa vadesi-geçmişe dokunmadıysa ve gerçek bir tek-taraflı risk varsa: temel ifade ──
  IF NOT ('net_pozisyon' = ANY(kodlar) OR 'veri_makul' = ANY(kodlar))
     AND COALESCE(vgecmis,0) > 1000000 THEN
    bulgular := bulgular || ('vadesi geçmiş bakiye '||_mln(vgecmis)||' milyon TL'||
      CASE WHEN limit_k>0 AND vgecmis>limit_k THEN '; kredi limiti '||_mln(limit_k)||'M — limit aşılmış (limit güncel olmayabilir)' ELSE '' END);
  END IF;

  -- ── ödeme hızı (domain) ──
  IF tahsil_gun IS NOT NULL AND tahsil_gun > 0 THEN
    bulgular := bulgular || ('ortalama tahsilat süresi '||round(tahsil_gun)||' gün'||CASE WHEN vade IS NOT NULL THEN ' (vade: '||vade||')' ELSE '' END);
  END IF;

  IF 'veri_makul' = ANY(kodlar) THEN guv := 'kismi'; END IF;
  oneri := CASE
    WHEN ciro_o>0 AND ciro_s=0 THEN 'Öneri: temsilci ('||COALESCE(rep,'-')||') acil ziyaret etsin; alım neden durdu öğrenilsin.'
    WHEN 'net_pozisyon' = ANY(kodlar) THEN 'Öneri: alacak-borç mutabakatı/takas; net başabaşsa öncelik düşük.'
    WHEN 'veri_makul' = ANY(kodlar) THEN 'Öneri: önce bu bakiyeyi muhasebeyle doğrula; kirli olabilir.'
    WHEN COALESCE(vgecmis,0)>1000000 THEN 'Öneri: tahsilat planı; yeni sevkiyatı bakiye netleşene kadar gözden geçir.'
    ELSE 'Öneri: ilişkiyi izle.' END;

  RETURN jsonb_build_object('musteri',ad,'kod',p_kod,'guven',guv,'oneri',oneri,
    'uygulanan_yasalar',to_jsonb(kodlar),
    'facts',jsonb_build_object('musteri',ad,'temsilci',rep,'guven',guv,'bulgular',to_jsonb(bulgular)));
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ sebep_arastir_musteri (ince — yasalar runner'dan)"

hr "2. MUTAFLAR — net bulgusu artık YASADAN geliyor (gömülü değil)"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_musteri('$T'::uuid,'M4115532'))" 2>&1 | sed 's/^/  /'

hr "3. ROTA — yasa yok, temel tek-taraflı risk ifadesi"
K=$($PSQL -tA -c "SELECT muhatap_kodu FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND muhatap_adi ILIKE '%ROTA LAST%' LIMIT 1;")
$PSQL -c "SELECT (sebep_arastir_musteri('$T'::uuid,'$K'))->'facts'->'bulgular' rota_bulgular, (sebep_arastir_musteri('$T'::uuid,'$K'))->'uygulanan_yasalar' yasalar;" 2>&1 | sed 's/^/  /'

hr "BITTI — yama çıktı: net/sanity artık TEK yerde (bi_yasa). Üretici ince. Sırada: hunter."
