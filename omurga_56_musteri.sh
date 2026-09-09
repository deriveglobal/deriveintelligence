#!/usr/bin/env bash
# OMURGA 56 — MÜŞTERİ domain (stres testi): sebep_arastir_musteri + icgoru_uret_musteri.
# Aynı desen, farklı şekil (davranış/zaman). Veri-mantık öz-denetimi dahil.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. Join anahtarı testi — MUTAFLAR (M4115532) satışta var mı"
$PSQL -c "SELECT count(*) satir, round(sum(satir_tutar)/1e6,1) toplam_M FROM bi_satis_faturalari WHERE tenant_id::text='$T' AND musteri_kodu='M4115532';" 2>&1 | sed 's/^/  /'

hr "1. sebep_arastir_musteri(tenant, kod)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_musteri(p_tenant uuid, p_kod text) RETURNS jsonb AS $fn$
DECLARE
  m0 date := date_trunc('month',CURRENT_DATE)::date;
  ad text; rep text; vade text; vgecmis numeric; limit_k numeric; bakiye numeric; c21 numeric;
  tahsil_gun numeric; ciro_s numeric; ciro_o numeric; yillik numeric;
  bulgular text[] := '{}'; guv text := 'yaklasik'; oneri text; supheli boolean := false;
BEGIN
  SELECT muhatap_adi, satis_calisani, odeme_kosulu, vadesi_gecmis, kredi_limiti, hesap_bakiyesi, ciro_2021
    INTO ad, rep, vade, vgecmis, limit_k, bakiye, c21
    FROM bi_musteri_risk WHERE tenant_id=p_tenant AND muhatap_kodu=p_kod;
  IF ad IS NULL THEN
    SELECT max(musteri_adi) INTO ad FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND musteri_kodu=p_kod;
  END IF;
  SELECT ort_tahsilat_gun INTO tahsil_gun FROM bi_musteri_risk_odeme WHERE tenant_id=p_tenant AND muhatap_kodu=p_kod LIMIT 1;
  SELECT sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '6 month' AND fatura_tarihi<m0),
         sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '12 month' AND fatura_tarihi<m0-interval '6 month')
    INTO ciro_s, ciro_o
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND musteri_kodu=p_kod AND fatura_tarihi>=m0-interval '12 month';
  ciro_s := COALESCE(ciro_s,0); ciro_o := COALESCE(ciro_o,0);
  yillik := GREATEST(ciro_s*2, COALESCE(c21,0));   -- kaba yıllık ciro tahmini

  -- CİRO TRENDİ
  IF ciro_o>0 AND ciro_s=0 THEN
    bulgular := bulgular || (ad||' son 6 ayda hiç alım yapmadı; önceki 6 ayda '||replace(round(ciro_o/1e6,1)::text,'.',',')||' milyon TL almıştı — sessiz kayıp riski');
  ELSIF ciro_o>0 AND ciro_s < ciro_o*0.7 THEN
    bulgular := bulgular || (ad||' cirosu son 6 ayda '||replace(round(ciro_o/1e6,1)::text,'.',',')||' milyon TL''den '||replace(round(ciro_s/1e6,1)::text,'.',',')||' milyon TL''ye düştü (%'||round(100*(ciro_s-ciro_o)/ciro_o)||')');
  ELSIF ciro_o>0 AND ciro_s > ciro_o*1.5 THEN
    bulgular := bulgular || (ad||' cirosu son 6 ayda '||replace(round(ciro_o/1e6,1)::text,'.',',')||'M''den '||replace(round(ciro_s/1e6,1)::text,'.',',')||'M''ye büyüdü (%'||round(100*(ciro_s-ciro_o)/ciro_o)||') — fırsat');
  END IF;

  -- VADESİ GEÇMİŞ + veri-mantık öz-denetimi
  IF vgecmis IS NOT NULL AND vgecmis > 1000000 THEN
    IF yillik>0 AND vgecmis > yillik*1.5 THEN
      supheli := true;
      bulgular := bulgular || ('vadesi geçmiş bakiye '||replace(round(vgecmis/1e6,1)::text,'.',',')||' milyon TL görünüyor, ANCAK bu müşterinin yıllık cirosundan (~'||replace(round(yillik/1e6,1)::text,'.',',')||'M) büyük — rakam veri hatası olabilir, muhasebeyle teyit edilmeli');
    ELSE
      bulgular := bulgular || ('vadesi geçmiş bakiye '||replace(round(vgecmis/1e6,1)::text,'.',',')||' milyon TL'||CASE WHEN limit_k>0 AND vgecmis>limit_k THEN '; kredi limiti '||replace(round(limit_k/1e6,1)::text,'.',',')||'M — limit aşılmış (limit güncel olmayabilir)' ELSE '' END);
    END IF;
  END IF;

  -- ÖDEME HIZI
  IF tahsil_gun IS NOT NULL AND tahsil_gun > 0 THEN
    bulgular := bulgular || ('ortalama tahsilat süresi '||round(tahsil_gun)||' gün'||CASE WHEN vade IS NOT NULL THEN ' (vade koşulu: '||vade||')' ELSE '' END);
  END IF;

  guv := CASE WHEN supheli THEN 'kismi' ELSE 'yaklasik' END;
  oneri := CASE
    WHEN ciro_o>0 AND ciro_s=0 THEN 'Öneri: temsilci ('||COALESCE(rep,'-')||') acil ziyaret etsin; neden alım durdu öğrenilsin.'
    WHEN supheli THEN 'Öneri: önce bu bakiye rakamını muhasebeyle doğrula; kirli olabilir.'
    WHEN vgecmis>1000000 THEN 'Öneri: tahsilat planı; yeni sevkiyatı bakiye netleşene kadar gözden geçir.'
    ELSE 'Öneri: ilişkiyi izle.' END;

  RETURN jsonb_build_object('musteri',ad,'kod',p_kod,'guven',guv,'oneri',oneri,
    'facts',jsonb_build_object('musteri',ad,'temsilci',rep,'guven',guv,'bulgular',to_jsonb(bulgular)));
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ sebep_arastir_musteri"

hr "2. icgoru_uret_musteri — kayda değer müşteriyi seç (bolum='musteri')"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION icgoru_uret_musteri(p_tenant uuid) RETURNS int AS $fn$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='musteri' AND durum='yeni';
  WITH s AS (
    SELECT musteri_kodu kod, max(musteri_adi) ad,
      sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '6 month' AND fatura_tarihi<m0) cs,
      sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '12 month' AND fatura_tarihi<m0-interval '6 month') co
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND fatura_tarihi>=m0-interval '12 month' GROUP BY musteri_kodu),
  r AS (SELECT muhatap_kodu kod, muhatap_adi ad, vadesi_gecmis vg FROM bi_musteri_risk WHERE tenant_id=p_tenant AND COALESCE(musteri_mi,true)),
  j AS (
    SELECT COALESCE(s.kod,r.kod) kod, COALESCE(r.ad,s.ad) ad,
           COALESCE(s.cs,0) cs, COALESCE(s.co,0) co, COALESCE(r.vg,0) vg
    FROM s FULL OUTER JOIN r ON s.kod=r.kod)
  INSERT INTO bi_icgoru (tenant_id,bolum,tip,ozet,kanit,surpriz_skoru,guven,durum)
  SELECT p_tenant,'musteri',
    CASE WHEN co>0 AND cs<co*0.5 THEN 'ciro-dususu' ELSE 'tahsilat-riski' END,
    ad||': '||CASE WHEN co>0 AND cs<co*0.5 THEN 'ciro '||round(co/1e6,1)||'→'||round(cs/1e6,1)||'M' ELSE 'vadesi geçmiş '||round(vg/1e6,1)||'M' END,
    jsonb_build_object('kod',kod,'musteri',ad,'ciro_o_m',round(co/1e6,1),'ciro_s_m',round(cs/1e6,1),'vadesi_gecmis_m',round(vg/1e6,1)),
    round(vg/1e6 + greatest(0,(co-cs)/1e6)),
    'yaklasik','yeni'
  FROM j
  WHERE kod IS NOT NULL AND ( vg > 5000000 OR (co > 3000000 AND cs < co*0.6) );
  SELECT count(*) INTO n FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='musteri' AND durum='yeni';
  RETURN n;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ icgoru_uret_musteri"

hr "3. ÇALIŞTIR — kaç kayda değer müşteri + ilk 8"
$PSQL -c "SELECT icgoru_uret_musteri('$T'::uuid) AS secilen;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT surpriz_skoru skor, tip, ozet FROM bi_icgoru WHERE tenant_id='$T'::uuid AND bolum='musteri' AND durum='yeni' ORDER BY surpriz_skoru DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "4. sebep_arastir_musteri — MUTAFLAR (şüpheli-bakiye öz-denetimi çalışıyor mu)"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_musteri('$T'::uuid,'M4115532'));" 2>&1 | sed 's/^/  /'

hr "BITTI — müşteri facts üreticisi + seçici. Sonra LLM anlatı (müşteri promptu) + endpoint genelleştir."
