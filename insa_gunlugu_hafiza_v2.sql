-- insa_gunlugu_hafiza_v2.sql — bi_insa_gunlugu GLOBAL, tenant_id YOK. Sadece yapı/kural.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'HAFIZA_V2',
  'Davranış madencisi: canlı veriden (bi_tahsilat ödeme davranışı, bi_satis alım trendi) deterministik olarak KALICI davranış örüntüsü türetip hafızaya kaynak=gozlem (yüksek güven) yazar. Günde ~1 kez otomatik + davranis_yenile aracıyla talep üzerine. LLM YOK, veriden türer, sayı uydurmaz.',
  'İnsan yalan söyler, davranış söylemez. Beyan (söylenen) güvenilmez; asıl kandırmaya-dirençli hafıza VERİDEN gözlenen davranıştır. DSO kartının ad-hoc yaptığını (müşteri "öderim" der, veri 122g gösterir) sistemleştirir.',
  jsonb_build_object(
    'odeme','bi_tahsilat top-40 müşteri (son12_tutar): son12_suresi>=55g veya son12_gec_orani>=0.45 → "kronik yavaş/geç ödeyen"; süre<=18g ve gec<=0.12 → "hızlı ve disiplinli ödeyen"; arası atlanır (gürültü yok). İsim bi_musteri_risk''ten.',
    'trend','bi_satis_faturalari son 6 tam ay: son3 < önceki3×0.6 → "alımını belirgin azalttı (kayıp riski)"; son3 > önceki3×1.5 → "alımını belirgin artırdı (büyüyen)". min 4 ay veri.',
    'guardrail','⚠ Sayı DEĞİL kalıcı SINIF yazılır (kronik geç/hızlı/düşen/büyüyen); kesin gün/oran her zaman canlı SQL. Sınıf değişirse eski gözlem gecerli=false + yeni insert (öğrenme/güncelleme).',
    'tetik','_handleBrainChat''te fire-and-forget, tenant başına 20 saatte 1 (globalThis.__madenciLast). davranis_yenile aracı talep üzerine çalıştırır. konu=musteri_kodu|odeme / |trend (aile ayrımı).',
    'multi_tenant','Tümü tenant-scoped; top-40 göreli sıralama + evrensel eşikler → tenant-agnostik. gozlem gerçekleri hatırlamada beyandan önce sıralanır (HAFIZA_V15).'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HAFIZA_V2');
\echo 'bi_insa_gunlugu: HAFIZA_V2 eklendi.'
SELECT adim, left(ne,58) ozet FROM bi_insa_gunlugu WHERE adim='HAFIZA_V2';
