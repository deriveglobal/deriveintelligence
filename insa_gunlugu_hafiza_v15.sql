-- insa_gunlugu_hafiza_v15.sql — bi_insa_gunlugu GLOBAL, tenant_id YOK. Sadece yapı/kural.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'HAFIZA_V15',
  'Hafızaya BEYAN vs GÖZLEM ayrımı + "unut/düzelt". Her kalıcı gerçek kaynak=beyan|gozlem etiketli, gözlem beyandan yüksek güven; hatırlama gözlemi öne alır ve satırları (gözlem)/(beyan) işaretler. unut_hafiza aracı: kullanıcı "unut / yanlış tanıdın / geçerli değil" derse gecerli=false (soft-forget).',
  'İnsanlar (müşteri/temsilci/owner) asistanı kandırabilir; SÖYLENEN (beyan) güvenilmez, VERİDEN gözlenen davranış güvenilir. Söz-eylem çelişkisi en değerli sinyal. Ayrıca yanlış/test öğrenmeleri doğal konuşmayla temizlenebilmeli.',
  jsonb_build_object(
    'kaynak','beyan = kişinin söylediği iddia/tercih (düşük güven ~0.55); gozlem = veriden/ölçümden/davranıştan gözlenen kalıcı örüntü (yüksek güven ~0.9). Damıtıcı her öğeyi etiketler; emin değilse beyan.',
    'siralama','Hatırlamada ORDER BY (kaynak=gozlem) DESC, guven DESC, son_gorulme DESC. Promptta satırlar (gözlem)/(beyan) etiketli; çelişirse gözleme güven, söz-eylem farkını fark et.',
    'unut','unut_hafiza(konu) → eşleşen kalıcı gerçek(ler) gecerli=false (silme değil, geçersizleme; iz kalır). Owner düzeltince ya da test kirliliğinde kullanılır. gecerli kolonu bunun için.',
    'not','v1.5 damıtıcı hâlâ KONUŞMAYI (çoğu beyan) işler; kandırmaya-dirençli GÖZLEM gerçekleri Faz 2 davranış madencisinden (bi_tahsilat/bi_satis/saha_ziyaret) gelecek. Bu katman zemini hazırlar.'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HAFIZA_V15');
\echo 'bi_insa_gunlugu: HAFIZA_V15 eklendi.'
SELECT adim, left(ne,58) ozet FROM bi_insa_gunlugu WHERE adim='HAFIZA_V15';
