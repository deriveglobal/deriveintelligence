#!/usr/bin/env bash
# OMURGA 49c — sebep_arastir_marj v5 (KENDİ-HAKEM düzeltmesi):
#  · maliyet NE'si ölçülü sürücü; NEDEN'i döviz (en eski vs en son, "seri kısa" uyarılı) ya da sor
#  · saha ipuçları YALNIZCA marka veya o markanın drag-ebatı geçerse (çöp yapışması yok)
#  · baskın faktörün kök-nedeni topraklanamazsa → ogren_sor
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. sebep_arastir_marj v5"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION sebep_arastir_marj(p_tenant uuid, p_marka text) RETURNS jsonb AS $fn$
DECLARE
  m0 date := date_trunc('month',CURRENT_DATE)::date;
  ciro_o numeric; ciro_s numeric; marjo_p numeric; marjs_p numeric;
  fiyat_et numeric; maliyet_et numeric; mix_et numeric; degisim numeric; marjo_m numeric; marjs_m numeric;
  esik numeric := 0.2;
  drivers text[] := '{}'; ask_why text[] := '{}'; saha text[] := '{}';
  usd_ilk numeric; usd_son numeric; usd_ilk_t date; usd_son_t date; lastik_s numeric; usd_delta int;
  tesvik_var int; iskonto_var int; sku_metni text; top_ebat text;
  sebep text; aksiyon text; guv text; soru_id uuid; kok_belirsiz boolean := false;
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

  -- ── MİX: düşük-marjlı büyüyen SKU'ları adlandır (NE + NEDEN kendinde) + drag-ebat kökü ──
  IF mix_et < -esik THEN
    SELECT string_agg(ebat||' ('||qo::int||'→'||qs::int||' ad, marj %'||marj||')', '; ' ORDER BY d DESC),
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
    IF sku_metni IS NOT NULL THEN drivers := drivers || ('MİX '||mix_et||'M: marka-altı marjlı ebatlara kayış → '||sku_metni);
    ELSE drivers := drivers || ('MİX '||mix_et||'M kötüleşti (tek SKU öne çıkmadı)'); kok_belirsiz:=true; ask_why:=ask_why||'mix dağınık'; END IF;
  END IF;

  -- ── MALİYET: NE ölçülü; NEDEN döviz (en eski vs en son, seri-kısa uyarılı) ya da sor ──
  IF maliyet_et < -esik THEN
    SELECT usd_try, gecerli_tarih INTO usd_ilk, usd_ilk_t FROM bi_ekonomik_parametreler ORDER BY gecerli_tarih ASC LIMIT 1;
    SELECT usd_try, gecerli_tarih, lastik_fiyat_artis_yillik_pct INTO usd_son, usd_son_t, lastik_s FROM bi_ekonomik_parametreler ORDER BY gecerli_tarih DESC LIMIT 1;
    IF usd_ilk IS NOT NULL AND usd_son > usd_ilk*1.05 THEN
      usd_delta := round(100*(usd_son-usd_ilk)/usd_ilk);
      drivers := drivers || ('MALİYET '||maliyet_et||'M arttı (birim maliyet dönemler arası yükseldi). Muhtemel neden: enflasyon/döviz — USD '||usd_ilk||'→'||usd_son||' (%'||usd_delta||'↑, '||to_char(usd_ilk_t,'DD Mon')||'–'||to_char(usd_son_t,'DD Mon')||'; ⚠ seri kısa, kesin bağ değil)');
    ELSE
      drivers := drivers || ('MALİYET '||maliyet_et||'M arttı (ölçülü). Kök nedeni doğrulanamadı — döviz serisi düz/eksik'); kok_belirsiz:=true; ask_why:=ask_why||'maliyet artışının kök nedeni (döviz/tedarikçi zammı)';
    END IF;
    SELECT count(*) INTO tesvik_var FROM bi_tedarikci_tesvik WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka);
    IF tesvik_var>0 THEN drivers := drivers || ('not: '||tesvik_var||' tedarikçi teşvik satırı maliyete KATILMADI → net marj bundan iyi olabilir'); END IF;
  END IF;

  -- ── FİYAT: NE ölçülü; NEDEN iskonto ya da sor ──
  IF fiyat_et < -esik THEN
    SELECT count(*) INTO iskonto_var FROM saha_iskonto_talep WHERE tenant_id=p_tenant AND upper(marka)=upper(p_marka);
    IF iskonto_var>0 THEN drivers := drivers || ('FİYAT '||fiyat_et||'M: ortalama fiyat düştü — '||iskonto_var||' onaylı iskonto talebi');
    ELSE drivers := drivers || ('FİYAT '||fiyat_et||'M: ortalama fiyat düştü ama iskonto çekmecesi BOŞ'); kok_belirsiz:=true; ask_why:=ask_why||'fiyat düşüşünün nedeni'; END IF;
  END IF;

  -- ── SAHA İSTİHBARATI: YALNIZCA marka VEYA bu markanın drag-ebatı geçerse ──
  SELECT array_agg(s) INTO saha FROM (
    SELECT DISTINCT left(coalesce(ozet,ham_metin,''),130) s, created_at FROM saha_sinyal
      WHERE tenant_id=p_tenant AND created_at>now()-interval '150 day'
        AND ( (coalesce(ozet,'')||' '||coalesce(ham_metin,'')) ILIKE '%'||p_marka||'%'
           OR (top_ebat IS NOT NULL AND (coalesce(ozet,'')||' '||coalesce(ham_metin,'')) ILIKE '%'||top_ebat||'%') )
    UNION ALL
    SELECT DISTINCT left('[PIYASA] '||coalesce(baslik,'')||' — '||coalesce(icerik,''),130) s, created_at FROM saha_duyuru
      WHERE tenant_id=p_tenant AND created_at>now()-interval '150 day'
        AND ( (coalesce(baslik,'')||' '||coalesce(icerik,'')) ILIKE '%'||p_marka||'%'
           OR (top_ebat IS NOT NULL AND (coalesce(baslik,'')||' '||coalesce(icerik,'')) ILIKE '%'||top_ebat||'%') )
    ORDER BY created_at DESC LIMIT 3) q;

  -- ── SONUÇ ──
  IF array_length(drivers,1) IS NULL THEN
    soru_id := ogren_sor(p_tenant,'sistem','marj:'||upper(p_marka),
      upper(p_marka)||' marjı %'||marjo_p||'→%'||marjs_p||' düştü ama köprüde belirgin faktör yok. Bir fikrin var mı?',
      'köprü maliyet '||maliyet_et||'M · mix '||mix_et||'M · fiyat '||fiyat_et||'M','["Tedarikçi","Rakip fiyat","Bilinçli hacim","İade/tek sefer","Başka"]'::jsonb);
    sebep := upper(p_marka)||' marjı düştü ama net faktör yok — sordum.'; aksiyon:='Cevap bekleniyor.'; guv:='belirsiz';
  ELSE
    sebep := upper(p_marka)||' marjı %'||marjo_p||'→%'||marjs_p||' düştü.  NE: '||array_to_string(drivers,'   ||   ');
    IF array_length(saha,1) IS NOT NULL THEN sebep := sebep||'   ||   SAHA (marka/ebat-eşleşen, doğrula): '||array_to_string(saha,'  •  '); END IF;
    IF kok_belirsiz THEN
      soru_id := ogren_sor(p_tenant,'sistem','marj-kok:'||upper(p_marka),
        upper(p_marka)||' marjı %'||marjo_p||'→%'||marjs_p||' düştü. Mekaniği ('||array_to_string(drivers,'; ')||') biliyorum ama KÖK NEDEN(ler)i çekmecelerde yok: '||array_to_string(ask_why,', ')||'. Sen biliyor musun?',
        'köprü maliyet '||maliyet_et||'M · mix '||mix_et||'M · fiyat '||fiyat_et||'M','["Tedarikçi maliyeti fırladı","Rakip fiyat baskısı","Bilinçli düşük-marj hacim","İade/tek sefer","Başka (yazacağım)"]'::jsonb);
      guv:='kismi';
    ELSE guv:='kesin'; END IF;
    aksiyon := CASE
      WHEN array_to_string(drivers,',') LIKE '%MİX%' AND array_to_string(drivers,',') LIKE '%MALİYET%'
        THEN 'Çift kaldıraç: maliyet-artan SKU''larda zam/teşvik-pazarlığı + zararına büyüyen ebatları fiyatla/kıs.'
      WHEN array_to_string(drivers,',') LIKE '%MİX%' THEN 'Adlandırılan ebatları fiyatla / yüksek-marjlıya yönel.'
      WHEN array_to_string(drivers,',') LIKE '%MALİYET%' THEN 'Zam + tedarikçi primini maliyete kat (net marj).'
      ELSE 'Fiyat/iskonto disiplinini gözden geçir.' END;
  END IF;

  RETURN jsonb_build_object('marka',upper(p_marka),'ciro_o_m',ciro_o,'ciro_s_m',ciro_s,
    'marj_pct_o',marjo_p,'marj_pct_s',marjs_p,'sebep',sebep,'aksiyon',aksiyon,'guven',guv,
    'kopru',jsonb_build_object('degisim_m',degisim,'fiyat_m',fiyat_et,'maliyet_m',maliyet_et,'mix_m',mix_et),
    'ne_drivers',to_jsonb(drivers),'saha_ipuclari',to_jsonb(saha),'sorulan_kok_soru',ask_why,
    'sorulan_soru_id',soru_id,'kaynak','bi_marj_atom + döviz + teşvik + iskonto + saha');
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ v5"

hr "2. CONTINENTAL (mix+maliyet; saha SADECE 205/55 & continental eşleşmeli)"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_marj('$T'::uuid,'CONTINENTAL'));" 2>&1 | sed 's/^/  /'

hr "3. LASSA (saha'da Sezer/Matador YAPIŞMAMALI)"
$PSQL -c "SELECT jsonb_pretty(sebep_arastir_marj('$T'::uuid,'LASSA'));" 2>&1 | sed 's/^/  /'

hr "4. HERKUL (205/55 YAPIŞMAMALI)"
$PSQL -c "SELECT (sebep_arastir_marj('$T'::uuid,'HERKUL'))->>'sebep' herkul, (sebep_arastir_marj('$T'::uuid,'HERKUL'))->'saha_ipuclari' saha;" 2>&1 | sed 's/^/  /'

hr "5. Üretilen kök-neden soruları"
$PSQL -c "SELECT anahtar, left(soru,90) FROM bi_sistem_sorusu WHERE tenant_id='$T'::uuid AND durum='acik' AND anahtar LIKE 'marj%';" 2>&1 | sed 's/^/  /'

hr "BITTI — v5 auditlendi: marka-özel saha, ölçülü maliyet + kök-neden sorusu."
