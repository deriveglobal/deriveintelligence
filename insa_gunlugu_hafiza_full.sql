-- insa_gunlugu_hafiza_full.sql — bi_insa_gunlugu GLOBAL, tenant_id YOK. Sadece yapı/kural.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'HAFIZA_FULL',
  'CEO Assistant kalıcı hafızası (bi_tenant_hafiza, tenant-scoped): otomatik damıtma (konuşma→kalıcı gerçek + kişi profili), alaka bazlı hatırlama (recency yerine konuya göre), beyan/gözlem ayrımı (gözlem>beyan güven), davranış madencisi (bi_tahsilat/bi_satis→gözlem), unut_hafiza (soft-forget). Tek birleşik sürüm.',
  '1. günden unutmayan + karşısındakini tanıyan asistan. İnsan yalan söyler davranış söylemez → gözlem beyandan güvenilir. Önceki parçalı sürüm _buildBrainPrompt imzasını bozup session (çok-tenant) referansını kırmıştı (500); bu sürüm session''ı gerçek parametre olarak geçirir, o gizli bug''ı da düzeltir.',
  jsonb_build_object(
    'kritik_fix','_buildBrainPrompt(tenantId) → (tenantId, session, _hMsg). Gövdedeki session.tenantConfig/tenantName artık gerçek session alır; çağrı _buildBrainPrompt(tenantId, session, userMsg). Runtime smoke test: session var/yok ikisinde de string döner, ReferenceError yok.',
    'damitma','Her turdan sonra fire-and-forget sonnet: sadece KALICI gerçek + kişi profili, kaynak=beyan|gozlem etiketli. OYNAK sayı ALMA. exact-dedup.',
    'hatirlama','hafizaCtx: konuya göre TÜM hafızada keyword-skor + son5 + kişi profili; ORDER BY gozlem-önce, guven, son_gorulme. Satırlar (gözlem)/(beyan).',
    'madenci','Günde ~1 otomatik + davranis_yenile: bi_tahsilat (kronik geç/hızlı ödeyen) + bi_satis (alım düşen/büyüyen) → gözlem. SAYI değil SINIF; kesin rakam canlı SQL. Sınıf değişince eski gözlem gecerli=false.',
    'guardrail','Oynak sayı/durum ASLA hafızaya. Hafıza canlı veriyi EZMEZ. Kişi profili yüze vurulmaz. bi_tenant_hafiza tenant-scoped (KRB per-tenant); global defter değil. Tablo CREATE race-safe (pg_type duplicate yut).'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HAFIZA_FULL');
\echo 'bi_insa_gunlugu: HAFIZA_FULL eklendi.'
SELECT adim, left(ne,58) ozet FROM bi_insa_gunlugu WHERE adim='HAFIZA_FULL';
