#!/usr/bin/env bash
# OMURGA 49b — sebep_arastir_marj v4: abs-fix + SAHA-METİN topraklaması (duyuru+sinyal).
# Köprü(sayı) + çekmece(döviz/teşvik/iskonto) + saha istihbaratı(insan-raporu) → gerçek sebep.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. sebep_arastir_marj v4"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_marj(p_tenant uuid, p_marka text) RETURNS jsonb AS $fn$
DECLARE
  m0 date := date_trunc('month',CURRENT_DATE)::date;
  ciro_o numeric; ciro_s numeric; marjo_p numeric; marjs_p numeric;
  fiyat_et numeric; maliyet_et numeric; mix_et numeric; degisim numeric; marjo_m numeric; marjs_m numeric;
  esik numeric := 0.2;
  drivers text[] := '{}'; kontrol text[] := '{}'; saha_ipuclari text[] := '{}';
  usd_o numeric; usd_s numeric; lastik_s numeric; tesvik_var int; iskonto_var int;
  sku_metni text; top_ebat text; usd_delta int;
  sebep text; aksiyon text; guv text; soru_id uuid;
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
    INTO ciro_o, ciro_s, marjo_m, marjs_m, marjo_p, marjs_p, fiyat_et, maliyet_et FROM a;
  degisim := round(marjs_m - marjo_m, 2);
  mix_et  := round(degisim - fiyat_et - maliyet_et, 2);

  IF marjs_p IS NULL OR marjo_p IS NULL THEN
    RETURN jsonb_build_object('marka',upper(p_marka),'sebep','Yeterli veri yok (atomda dönem eşleşmedi).','guven','yok'); END IF;
  IF marjs_p >= marjo_p THEN
    RETURN jsonb_build_object('marka',upper(p_marka),'marj_pct_o',marjo_p,'marj_pct_s',marjs_p,
      'sebep','Marj oranı düşmedi (%'||marjo_p||'→%'||marjs_p||').','aksiyon','Aksiyon yok.','guven','kesin'); END IF;

  -- MALİYET → döviz/enflasyon (abs gün cinsinden)
  IF maliyet_et < -esik THEN
    SELECT usd_try INTO usd_o FROM bi_ekonomik_parametreler ORDER BY abs(gecerli_tarih-(m0-interval '9 month')::date) LIMIT 1;
    SELECT usd_try, lastik_fiyat_artis_yillik_pct INTO usd_s, lastik_s FROM bi_ekonomik_parametreler ORDER BY abs(gecerli_tarih-(m0-interval '3 month')::date) LIMIT 1;
    IF usd_o IS NOT NULL AND usd_s IS NOT NULL AND usd_s > usd_o*1.05 THEN
      usd_delta := round(100*(usd_s-usd_o)/usd_o);
      drivers := drivers || ('maliyet artışı '||maliyet_et||'M — dönemde USD/TRY %'||usd_delta||'↑'||
                 COALESCE(' (lastik yıllık %'||round(lastik_s)||'↑)','')||': enflasyon/döviz geçişi');
    ELSE
      kontrol := kontrol || ('maliyet '||maliyet_et||'M arttı ama döviz çekmecesi düz/eksik — nedeni doğrulanamadı');
    END IF;
    SELECT count(*) INTO tesvik_var FROM bi_tedarikci_tesvik WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka);
    IF tesvik_var>0 THEN kontrol := kontrol || (tesvik_var||' tedarikçi teşvik satırı VAR ama maliyete katılmadı — net marj daha iyi olabilir'); END IF;
  END IF;

  -- MİX → düşük-marjlı büyüyen SKU'ları adlandır + en büyüğünün ebat kökünü al
  IF mix_et < -esik THEN
    SELECT string_agg(ebat||' ('||qo||'→'||qs||' ad, marj %'||marj||')', '; ' ORDER BY d DESC),
           split_part((array_agg(ebat ORDER BY d DESC))[1],'R',1)
      INTO sku_metni, top_ebat FROM (
        SELECT max(ebat) ebat,
          sum(adet) FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') qo,
          sum(adet) FILTER (WHERE ay>=m0-interval '6 month' AND ay<m0) qs,
          round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj,
          sum(adet) FILTER (WHERE ay>=m0-interval '6 month' AND ay<m0)
            - sum(adet) FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') d
        FROM bi_marj_atom WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka) AND ay>=m0-interval '12 month'
        GROUP BY kalem_kodu
        HAVING sum(adet) FILTER (WHERE ay>=m0-interval '6 month' AND ay<m0)
             > sum(adet) FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month')
           AND round(100*sum(brut_kar)/nullif(sum(ciro),0),1) < marjs_p
        ORDER BY d DESC LIMIT 3) z;
    IF sku_metni IS NOT NULL THEN
      drivers := drivers || ('mix '||mix_et||'M — marka-altı marjlı ürünlere kayış: '||sku_metni);
    ELSE kontrol := kontrol || ('mix '||mix_et||'M kötüleşti ama tek SKU öne çıkmadı'); END IF;
  END IF;

  -- FİYAT → iskonto
  IF fiyat_et < -esik THEN
    SELECT count(*) INTO iskonto_var FROM saha_iskonto_talep WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka);
    IF iskonto_var>0 THEN drivers := drivers || ('ortalama fiyat '||fiyat_et||'M düştü — '||iskonto_var||' onaylı iskonto');
    ELSE kontrol := kontrol || ('ortalama fiyat '||fiyat_et||'M düştü ama iskonto çekmecesi BOŞ — doğrulanamadı'); END IF;
  END IF;

  -- ── SAHA İSTİHBARATI: duyuru + sinyal metinleri (marka VEYA drag-ebat VEYA rekabet) ──
  SELECT array_agg(s) INTO saha_ipuclari FROM (
    SELECT DISTINCT left(coalesce(ozet,ham_metin,''),130) s, created_at FROM saha_sinyal
      WHERE tenant_id=p_tenant AND created_at > now()-interval '150 day'
        AND (coalesce(ozet,'')||' '||coalesce(ham_metin,''))
            ILIKE ANY (ARRAY['%'||p_marka||'%', '%'||COALESCE(top_ebat,'§yok§')||'%','%rakip%','%zam%','%indirim%','%kampanya%','%matador%'])
    UNION ALL
    SELECT DISTINCT left('[PIYASA] '||coalesce(baslik,'')||' — '||coalesce(icerik,''),130) s, created_at FROM saha_duyuru
      WHERE tenant_id=p_tenant AND tip='PIYASA' AND created_at > now()-interval '150 day'
    ORDER BY created_at DESC LIMIT 4) q;
  IF array_length(saha_ipuclari,1) IS NOT NULL THEN
    drivers := drivers || ('saha ipuçları (insan-raporu, doğrulama gerekir): '||array_to_string(saha_ipuclari,'  •  '));
  END IF;

  -- ── SONUÇ ──
  IF array_length(drivers,1) IS NULL THEN
    soru_id := ogren_sor(p_tenant,'sistem','marj:'||upper(p_marka),
      upper(p_marka)||' marjı %'||marjo_p||'→%'||marjs_p||' düştü. Tüm çekmeceleri (döviz/teşvik/mix/iskonto/saha) açtım ama net sebep yok. Sen biliyor musun?',
      'köprü: maliyet '||maliyet_et||'M · mix '||mix_et||'M · fiyat '||fiyat_et||'M · kontrol: '||array_to_string(kontrol,' | '),
      '["Tedarikçi maliyeti fırladı","Rakip fiyat baskısı","Bilinçli düşük-marj hacim","Tek seferlik/iade","Başka (yazacağım)"]'::jsonb);
    sebep := upper(p_marka)||' marjı %'||marjo_p||'→%'||marjs_p||' düştü. Çekmecelerde açıklama YOK — sana sordum (öğrenme).';
    aksiyon := 'Soru kaydedildi; cevabın gelince bu deseni hatırlayacağım.'; guv := 'belirsiz';
  ELSE
    sebep := 'Marj %'||marjo_p||'→%'||marjs_p||' düştü. Sebep(ler): '||array_to_string(drivers,'  ||  ');
    aksiyon := CASE
      WHEN array_to_string(drivers,',') LIKE '%mix%' AND array_to_string(drivers,',') LIKE '%maliyet%'
        THEN 'Çift kaldıraç: (1) maliyet-artan SKU''larda zam/teşvik-pazarlığı, (2) zararına büyüyen ebatları fiyatla/kıs (saha ipuçlarını doğrula).'
      WHEN array_to_string(drivers,',') LIKE '%mix%' THEN 'Fiyat değil mix — adlandırılan ebatları fiyatla; saha rekabet ipuçlarını kontrol et.'
      WHEN array_to_string(drivers,',') LIKE '%maliyet%' THEN 'Maliyet enflasyonu — zam + tedarikçi primini maliyete kat.'
      ELSE 'Fiyat/iskonto disiplinini gözden geçir.' END;
    guv := CASE WHEN array_length(kontrol,1) IS NULL THEN 'kesin' ELSE 'kismi' END;
  END IF;

  RETURN jsonb_build_object('marka',upper(p_marka),'ciro_o_m',ciro_o,'ciro_s_m',ciro_s,
    'marj_pct_o',marjo_p,'marj_pct_s',marjs_p,'sebep',sebep,'aksiyon',aksiyon,'guven',guv,
    'kopru',jsonb_build_object('degisim_m',degisim,'fiyat_m',fiyat_et,'maliyet_m',maliyet_et,'mix_m',mix_et),
    'topraklanan',to_jsonb(drivers),'saha_ipuclari',to_jsonb(saha_ipuclari),
    'kontrol_edildi_bos',to_jsonb(kontrol),'sorulan_soru_id',soru_id,
    'kaynak','bi_marj_atom + çekmece + saha istihbaratı');
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ sebep_arastir_marj v4"

hr "2. CONTINENTAL — maliyet(döviz)+mix(SKU)+saha(Matador 205/55) birlikte"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_marj('$T'::uuid,'CONTINENTAL'));" 2>&1 | sed 's/^/  /'

hr "3. LASSA + HERKUL sebep"
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'LASSA'))->>'sebep' lassa;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'HERKUL'))->>'sebep' herkul;" 2>&1 | sed 's/^/  /'

hr "4. honest-null kontrolü — grounded markalar soru üretmedi mi"
$PSQL -c "SELECT count(*) acik_marj_sorusu FROM bi_sistem_sorusu WHERE tenant_id='$T'::uuid AND durum='acik' AND anahtar LIKE 'marj:%';" 2>&1 | sed 's/^/  /'

hr "BITTI — v4: sayı + çekmece + saha istihbaratı tek sebep hikayesinde."
