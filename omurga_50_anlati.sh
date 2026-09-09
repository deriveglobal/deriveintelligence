#!/usr/bin/env bash
# OMURGA 50 — sebep_arastir_marj v6: insan-sesli 'anlati' (akıcı Türkçe, etiketsiz).
# Tespit mantığı v5.1 ile AYNI (grounded); sadece metin insan gibi kuruluyor. LLM yok, sayı uydurma yok.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. sebep_arastir_marj v6 (anlati)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_marj(p_tenant uuid, p_marka text) RETURNS jsonb AS $fn$
DECLARE
  m0 date := date_trunc('month',CURRENT_DATE)::date;
  ciro_o numeric; ciro_s numeric; marjo_p numeric; marjs_p numeric;
  fiyat_et numeric; maliyet_et numeric; mix_et numeric; degisim numeric; marjo_m numeric; marjs_m numeric;
  esik numeric := 0.2;
  ne_yapi text[] := '{}'; saha text[] := '{}'; ask_why text[] := '{}';
  usd_ilk numeric; usd_son numeric; usd_ilk_t date; usd_son_t date; usd_delta int;
  tesvik_var int; iskonto_var int; sku_metni text; top_ebat text;
  t_ebat text; t_qo int; t_qs int; t_marj numeric;
  c_mix text; c_mal text; c_fiy text; mag_mix numeric; mag_mal numeric; mag_fiy numeric;
  govde text; anlati text; oneri text; guv text; soru_id uuid;
  kok_belirsiz boolean := false; caveat_used boolean := false;
  mtitle text := upper(left(lower(p_marka),1))||substr(lower(p_marka),2);
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
    RETURN jsonb_build_object('marka',upper(p_marka),'anlati',mtitle||' için dönem-eşleşen yeterli veri yok.','guven','yok'); END IF;
  IF marjs_p >= marjo_p THEN
    RETURN jsonb_build_object('marka',upper(p_marka),'marj_pct_o',marjo_p,'marj_pct_s',marjs_p,
      'anlati',mtitle||' markasında marj bu dönemde düşmedi (%'||replace(marjo_p::text,'.',',')||' → %'||replace(marjs_p::text,'.',',')||'), bir aksiyon gerekmiyor.','guven','kesin'); END IF;

  -- MİX
  IF mix_et < -esik THEN
    SELECT string_agg(ebat||' ('||qo::int||'→'||qs::int||' ad, marj %'||marj||')','; ' ORDER BY d DESC),
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
      SELECT ebat, qo::int, qs::int, marj INTO t_ebat,t_qo,t_qs,t_marj FROM (
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
        ORDER BY d DESC LIMIT 1) z1;
      c_mix := 'satış karması düşük marjlı ürünlere kaydı; en dikkat çekeni '||t_ebat||': bu ebadı altı ayda '||t_qo||' adetten '||t_qs||' adede çıkarmışsınız, ama üründe marj %'||replace(t_marj::text,'.',',')||' — yani fiilen zararına satılıyor'||
               CASE WHEN sku_metni LIKE '%;%' THEN ' (birkaç ebat daha benzer durumda)' ELSE '' END;
      mag_mix := abs(mix_et); ne_yapi := ne_yapi||('mix '||mix_et||'M: '||sku_metni);
    ELSE kok_belirsiz:=true; ask_why:=ask_why||'karışımın neden bozulduğu'; END IF;
  END IF;

  -- MALİYET
  IF maliyet_et < -esik THEN
    SELECT usd_try, gecerli_tarih INTO usd_ilk, usd_ilk_t FROM bi_ekonomik_parametreler ORDER BY gecerli_tarih ASC LIMIT 1;
    SELECT usd_try, gecerli_tarih INTO usd_son, usd_son_t FROM bi_ekonomik_parametreler ORDER BY gecerli_tarih DESC LIMIT 1;
    IF usd_ilk IS NOT NULL AND usd_son > usd_ilk*1.05 THEN
      usd_delta := round(100*(usd_son-usd_ilk)/usd_ilk); caveat_used:=true;
      c_mal := 'birim maliyetler yükseldi ve bu tek başına marja yaklaşık '||replace(round(abs(maliyet_et),1)::text,'.',',')||' milyon TL baskı yaptı; büyük olasılıkla kur/enflasyon kaynaklı — dolar bu dönemde %'||usd_delta||' arttı, ama elimizdeki kur verisi kısa olduğu için bunu kesin sebep olarak sunmuyorum';
    ELSE
      c_mal := 'birim maliyetler yükseldi ve marja yaklaşık '||replace(round(abs(maliyet_et),1)::text,'.',',')||' milyon TL baskı yaptı, ama kök nedenini verilerde doğrulayamadım';
      kok_belirsiz:=true; ask_why:=ask_why||'maliyet artışının kök nedeni';
    END IF;
    mag_mal := abs(maliyet_et); ne_yapi := ne_yapi||('maliyet '||maliyet_et||'M');
    SELECT count(*) INTO tesvik_var FROM bi_tedarikci_tesvik WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka);
  END IF;

  -- FİYAT
  IF fiyat_et < -esik THEN
    SELECT count(*) INTO iskonto_var FROM saha_iskonto_talep WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka);
    IF iskonto_var>0 THEN c_fiy := 'ortalama satış fiyatı geriledi (yaklaşık '||replace(round(abs(fiyat_et),1)::text,'.',',')||' milyon TL etki); bunu açıklayan '||iskonto_var||' onaylı iskonto talebi var';
    ELSE c_fiy := 'ortalama satış fiyatı geriledi (yaklaşık '||replace(round(abs(fiyat_et),1)::text,'.',',')||' milyon TL etki), ama iskonto kayıtlarında bunun karşılığını bulamadım'; kok_belirsiz:=true; ask_why:=ask_why||'fiyat düşüşünün nedeni'; END IF;
    mag_fiy := abs(fiyat_et); ne_yapi := ne_yapi||('fiyat '||fiyat_et||'M');
  END IF;

  -- SAHA: yalnızca TALEP sürücüsü (mix/fiyat) varsa VE not markayı ya da BU markanın drag-ebatını içerirse.
  --       Saf-maliyet düşüşünde saha eklenmez (maliyeti açıklamaz). Global rakip-kelime YOK (yanlış markaya yapışmasın).
  IF c_mix IS NOT NULL OR c_fiy IS NOT NULL THEN
    SELECT array_agg(s) INTO saha FROM (
      SELECT DISTINCT left(coalesce(ozet,ham_metin,''),130) s, created_at FROM saha_sinyal
        WHERE tenant_id=p_tenant AND created_at>now()-interval '150 day'
          AND ( (coalesce(ozet,'')||' '||coalesce(ham_metin,'')) ILIKE '%'||p_marka||'%'
             OR (top_ebat IS NOT NULL AND (coalesce(ozet,'')||' '||coalesce(ham_metin,'')) ILIKE '%'||top_ebat||'%') )
      UNION ALL
      SELECT DISTINCT left(coalesce(baslik,'')||' — '||coalesce(icerik,''),130) s, created_at FROM saha_duyuru
        WHERE tenant_id=p_tenant AND created_at>now()-interval '150 day'
          AND ( (coalesce(baslik,'')||' '||coalesce(icerik,'')) ILIKE '%'||p_marka||'%'
             OR (top_ebat IS NOT NULL AND (coalesce(baslik,'')||' '||coalesce(icerik,'')) ILIKE '%'||top_ebat||'%') )
      ORDER BY created_at DESC LIMIT 2) q;
  END IF;

  -- GÖVDE: faktörleri büyüklüğe göre insan cümleleriyle sırala
  IF c_mix IS NULL AND c_mal IS NULL AND c_fiy IS NULL THEN
    soru_id := ogren_sor(p_tenant,'sistem','marj:'||upper(p_marka),
      mtitle||' marjı %'||replace(marjo_p::text,'.',',')||'→%'||replace(marjs_p::text,'.',',')||' düştü ama köprüde belirgin faktör yok. Bir fikrin var mı?',
      'maliyet '||maliyet_et||'M · mix '||mix_et||'M · fiyat '||fiyat_et||'M','["Tedarikçi","Rakip fiyat","Bilinçli hacim","İade/tek sefer","Başka"]'::jsonb);
    anlati := mtitle||' markasında marj %'||replace(marjo_p::text,'.',',')||' seviyesinden %'||replace(marjs_p::text,'.',',')||' seviyesine geriledi, ama bunu bir faktöre bağlayamadım. Bir fikrin varsa öğrenmek isterim.';
    oneri := 'Cevabını bekliyorum.'; guv:='belirsiz';
  ELSE
    SELECT string_agg(CASE rn WHEN 1 THEN upper(left(c,1))||substr(c,2) WHEN 2 THEN 'buna ek olarak, '||c ELSE 'ayrıca '||c END,
                      CASE WHEN rn=1 THEN '' ELSE '; ' END ORDER BY rn) INTO govde
      FROM (SELECT c, row_number() over(order by mag desc) rn FROM (VALUES (mag_mix,c_mix),(mag_mal,c_mal),(mag_fiy,c_fiy)) v(mag,c) WHERE c IS NOT NULL) z;

    anlati := mtitle||' markasında marj son altı ayda %'||replace(marjo_p::text,'.',',')||' seviyesinden %'||replace(marjs_p::text,'.',',')||' seviyesine geriledi. '||govde||'.';
    IF array_length(saha,1) IS NOT NULL AND (c_mix IS NOT NULL OR c_fiy IS NOT NULL) THEN
      anlati := anlati||' Sahadan da şu rekabet sinyali geliyor: '||array_to_string(saha,'; ')||' (doğrulamakta fayda var).'; END IF;
    IF tesvik_var IS NOT NULL AND tesvik_var>0 THEN
      anlati := anlati||' Şunu da hatırlatayım: '||tesvik_var||' tedarikçi teşviki henüz maliyet hesabına girmedi, dolayısıyla gerçek marj göründüğünden bir miktar daha iyi olabilir.'; END IF;
    IF kok_belirsiz THEN
      soru_id := ogren_sor(p_tenant,'sistem','marj-kok:'||upper(p_marka),
        mtitle||' marjı %'||replace(marjo_p::text,'.',',')||'→%'||replace(marjs_p::text,'.',',')||' düştü; mekaniğini görüyorum ama '||array_to_string(ask_why,' ve ')||' konusunda emin değilim. Sen biliyor musun?',
        array_to_string(ne_yapi,' · '),'["Tedarikçi maliyeti fırladı","Rakip fiyat baskısı","Bilinçli düşük-marj hacim","İade/tek sefer","Başka (yazacağım)"]'::jsonb);
      anlati := anlati||' Bir kısmını ben de tam çözemedim ('||array_to_string(ask_why,', ')||'); bu konuda bir bilgin varsa öğrenmek isterim.';
      guv:='kismi';
    ELSIF caveat_used THEN guv:='kismi'; ELSE guv:='kesin'; END IF;

    oneri := CASE
      WHEN c_mix IS NOT NULL AND c_mal IS NOT NULL THEN 'Önerim: hem maliyeti artan ürünlerde zam/tedarikçi primi pazarlığı yapın, hem de zararına büyüyen ebatları ya fiyatlandırın ya da hacmini kısın.'
      WHEN c_mix IS NOT NULL THEN 'Önerim: adı geçen ebatları yeniden fiyatlandırın ya da yüksek marjlı ürünlere yönelin.'
      WHEN c_mal IS NOT NULL THEN 'Önerim: fiyat güncellemesi yapın ve tedarikçi primini maliyet hesabına dahil edin.'
      ELSE 'Önerim: fiyat ve iskonto disiplinini gözden geçirin.' END;
  END IF;

  RETURN jsonb_build_object('marka',upper(p_marka),'anlati',anlati,'oneri',oneri,'guven',guv,
    'marj_pct_o',marjo_p,'marj_pct_s',marjs_p,'ciro_o_m',ciro_o,'ciro_s_m',ciro_s,
    'kopru',jsonb_build_object('degisim_m',degisim,'fiyat_m',fiyat_et,'maliyet_m',maliyet_et,'mix_m',mix_et),
    'ne_yapi',to_jsonb(ne_yapi),'saha_ipuclari',to_jsonb(saha),'sorulan_soru_id',soru_id,
    'facts',jsonb_build_object(
      'marka',mtitle,'marj_onceki_yuzde',marjo_p,'marj_simdi_yuzde',marjs_p,'guven',guv,
      'bulgular',to_jsonb(array_remove(ARRAY[c_mix,c_mal,c_fiy],NULL)),
      'tesvik_notu',CASE WHEN tesvik_var>0 THEN tesvik_var||' tedarikçi teşviki maliyete katılmadı; net marj bundan iyi olabilir' ELSE NULL END,
      'saha_ipuclari',to_jsonb(saha),'cozulemeyen',to_jsonb(ask_why)),
    'kaynak','bi_marj_atom + döviz + teşvik + iskonto + saha');
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ v6 (anlati)"

hr "2. CONTINENTAL — insan anlatısı"
$PSQL -tA -c "SELECT (sebep_arastir_marj('$T'::uuid,'CONTINENTAL'))->>'anlati';" 2>&1 | fold -s -w 100 | sed 's/^/  /'
echo "  ── öneri:"; $PSQL -tA -c "SELECT (sebep_arastir_marj('$T'::uuid,'CONTINENTAL'))->>'oneri';" 2>&1 | fold -s -w 100 | sed 's/^/  /'

hr "3. LASSA — insan anlatısı"
$PSQL -tA -c "SELECT (sebep_arastir_marj('$T'::uuid,'LASSA'))->>'anlati';" 2>&1 | fold -s -w 100 | sed 's/^/  /'

hr "4. HERKUL — insan anlatısı"
$PSQL -tA -c "SELECT (sebep_arastir_marj('$T'::uuid,'HERKUL'))->>'anlati';" 2>&1 | fold -s -w 100 | sed 's/^/  /'

hr "BITTI — insan-sesli anlati; yapısal alanlar makine için duruyor."
