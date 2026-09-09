-- insa_gunlugu_hafiza.sql — PLATFORM inşa günlüğü (bi_insa_gunlugu GLOBAL, tenant_id YOK).
-- ⚠ MULTI-TENANT: burada tenant'a özel SAYI/İSİM yok. Yalnız yapı/kural/formül.
--   bi_tenant_hafiza'nın gerçek içeriği tenant başına CANLI birikir (damıtma); bu defter yalnız MİMARİYİ anlatır.
-- Calistir: cat insa_gunlugu_hafiza.sql | ssh -i KEY root@... 'docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'HAFIZA_V1',
  'CEO Assistant (ana beyin) için "1. günden unutmayan" kalıcı hafıza + kişi profili. Yeni tablo bi_tenant_hafiza: şirket gerçeği (müşteri/karar/örüntü) ve konuşan kişinin profili (öncelik/üslup/beklenti) tek yapıda. Her turdan sonra otomatik damıtma, sistem promptuna alaka bazlı hatırlama enjekte edilir.',
  'Beyin geçmişi (brain_conversations) yalnız son 30 mesajı context''e alıyordu; eski bağlam tabloda dursa da görünmüyordu ("1. günden unutma" erişim problemiydi). Ayrıca yakalama fırsata bağlıydı (sadece save_note edilen kalıyordu). Bu katman ikisini de kapatır ve karşısındakini tanıyıp tonunu/proaktifliğini ayarlar.',
  jsonb_build_object(
    'tablo','bi_tenant_hafiza (tenant-scoped): user_id (kişi profili için), kategori (musteri|karar|oruntu|tercih|kisi_profili|oncelik|uslup|genel), konu (özne anahtarı), icerik (kalıcı gerçek), kisi (bool), guven, ilk_gorulme, son_gorulme, gecerli.',
    'damitma','Her chat turundan sonra fire-and-forget: son kullanıcı+asistan turu claude-sonnet-4-6 ile damıtılır; SADECE kalıcı gerçek (davranış/tercih/karar/örüntü) çıkarılır, exact-dedup + son_gorulme güncelleme ile upsert.',
    'hatirlama','getBrainPrompt: recency-30 yerine ALAKA bazlı — sorunun anahtar kelimelerine göre tüm hafızada eşleşenler + son N + kişi profili, token-bütçeli enjekte. 1. günün gerçeği ilgili konu açılınca yüzeye gelir.',
    'guardrail','⚠ OYNAK SAYI/DURUM ASLA hafızaya (bakiye/DSO/marj/tarih) — yalnız kalıcı gerçek. Hafıza İPUCU; canlı veriyi EZMEZ, sayı/durum için her zaman canlı araç. (GECMIS_ZEHRI_V1 dersi: model geçmiş cümlesini bugüne taşıyıp stale hüküm kurmuştu; kalıcı-gerçek disiplini bunu önler.) Kişi profili prompta işlenir ama YÜZE VURULMAZ.',
    'multi_tenant','bi_tenant_hafiza tenant-scoped: tenant''ın kalıcı gerçekleri orada yaşar (per-tenant veri). Global defterler (bi_insa_gunlugu, sistem haritası) sayısız kalır. Damıtma tenant_id + user_id ile yazar.'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HAFIZA_V1');

\echo 'bi_insa_gunlugu: HAFIZA_V1 (mimari) eklendi. Tenant hafizasi canli birikir.'
SELECT adim, left(ne,58) ozet FROM bi_insa_gunlugu WHERE adim='HAFIZA_V1';
