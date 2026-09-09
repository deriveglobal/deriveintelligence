-- insa_gunlugu_iki_is.sql — PLATFORM inşa günlüğü (bi_insa_gunlugu GLOBAL, tenant_id YOK).
-- ⚠ MULTI-TENANT: burada TENANT'A ÖZEL SAYI YOK (YEDİ, marj %, DSO gün...). Yalnız YAPI/KURAL/FORMÜL.
--   Tenant'ın gerçek sayıları asistanın execute_query ile CANLI hesaplanır (tenant_id session'dan). KRB tek tenant ama mimari korunur.
-- Calistir: cat insa_gunlugu_iki_is.sql | ssh -i KEY root@... 'docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'IKI_IS_KOKPIT',
  'Yeni "İki İş" (Tüketici·Ticari) finans kokpiti canlı — /app Finans odası bunu gösteriyor (kabuk /api/bi/kokpit-iki). Beş bölüm: Şirket · Çatal · Nakit · Kâr Haritası+Marka İzi · Müşteri Evreni. İşi TEK yerine İKİ ayrı iş olarak okur; her metrik ne ölçtüğü etiketli.',
  'Tüketici (binek/PSR) ve ticari (TBR/OTR/filo/retread) farklı işler; ortalamalar bunu gizliyordu. Kokpit ikiye ayırır.',
  jsonb_build_object(
    'siniflama_kural','TÜKETİCİ = kategori_segment(kategori)=''PSR'' (bi_marj_atom); TİCARİ = geri kalan (TBR/OTR/YENİLEME/LSR/IND/AG). Canlı ay için tük/tic = bi_satis_faturalari.grup_adi (''LASTIK TUKETICI''/''LASTIK TICARI''). Bu ayrım her marj/ciro/nakit sorusunda geçerli.',
    'ciro_vs_marj','Ciro = TÜM ŞİRKET (lastik+retread+servis+hammadde/jant, bi_satis_faturalari tüm grup_adi). Marj/Kâr/Müşteri = YALNIZ lastik işi (bi_marj_atom). Owner ciro sorarsa tüm şirket, marj sorarsa lastik işi — karıştırma.',
    'canli_ay','Bu ay = gerçek takvim ayı. Ciro/adet canlı (bi_satis_faturalari). Marj canlı ama muhasebe/dönem maliyeti bazı (bi_marj_atom son-bilinen birim_maliyet carry-forward), ay kapanınca kesinleşir. Kâr haritası/marka = son kapalı ay yapısı.',
    'not','Sayılar tenant''a göre CANLI hesaplanır (bu defter global). Owner soru sorarsa güncel tenant için execute_query ile hesapla.'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='IKI_IS_KOKPIT');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'IKI_IS_MARJ_TREND',
  'Aylık brüt-marj trendi yeteneği (lastik işi, son 13 ay + canlı ay), tüketici/ticari ayrı. Kokpitte Şirket bölümü altında sparkline.',
  'Tek-sayı (12-ay ortalama) marjın zaman içindeki iniş/çıkışını gizler. "Marjım neden düştü/değişti" sorusunda AYLIK trende bakılmalı — hangi ay, hangi iş kolu döndü.',
  jsonb_build_object(
    'nasil','bi_marj_atom aylik: SELECT ay, sum(brut_kar)/nullif(sum(ciro),0)*100 marj, kategori_segment ile PSR (tüketici) vs diğer (ticari) FILTER. Canlı ay marjı bi_tahsilat DEĞİL, faturalari×son-maliyet.',
    'kullanim','Owner "marj neden düştü/arttı" derse: aylik trendi tenant için çek, hangi ay ve hangi iş kolunun (tük/tic) döndüğünü göster; tek ortalamayla cevaplama.'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='IKI_IS_MARJ_TREND');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'IKI_IS_DSO',
  'İşe-bazında DSO/tahsilat teşhisi (Nakit bölümü + dso_ozet). Her iş kolu için: ÖLÇÜLEN ödeme süresi (bi_tahsilat, gerçek fatura→ödeme) vs DSO (bakiye/günlük-satış). İki ayrı soru: "ne hızda ödüyorlar" vs "kaç günlük satış defterde bağlı".',
  'Yüksek DSO tek başına "kötü tahsilat" demek DEĞİL. Ölçülen ödeme hızlı ama DSO yüksekse fark = birkaç ESKİ TAKILMIŞ HESAP (yoğunlaşma), sistemik değil. Owner gecikmiş toplamına panik yapmasın; teşhis hesap-bazlı mı sistemik mi ayırt edilmeli.',
  jsonb_build_object(
    'formul','DSO ham = bakiye / (12ay_ciro/365). DSO net = (bakiye−gecikmiş)/günlük. Ölçülen ödeme = bi_tahsilat son12_suresi (tutar-ağırlıklı). Sınıf = müşterinin baskın alışı (PSR=tüketici).',
    'tablolar','bi_musteri_risk (bakiye=hesap_bakiyesi, gecikmiş=FIFO net vadesi_gecmis+cari_bakiye mahsup) · bi_tahsilat (ölçülen ödeme) · bi_satis_faturalari×bi_marj_atom (sınıf).',
    'sinifsiz','Son 12 ay lastik alışı olmayan cariler (lastik-dışı alanlar + DORMANT/eski-bakiye). Owner "şu borçlu ama almıyor" derse burası.',
    'teshis_deseni','Ölçülen ödeme DÜŞÜK + DSO YÜKSEK + gecikmiş tek hesapta yoğun => "hızlı ödüyorlar, birkaç eski hesap şişiriyor, o hesabı kapat". Fark küçük/yayılmış => "genel disiplin, vade ayarı".'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='IKI_IS_DSO');

\echo 'bi_insa_gunlugu: IKI_IS_* (tenant-agnostik yapi/kural) eklendi. Tenant sayilari canli hesaplanir.'
SELECT adim, left(ne,58) ozet FROM bi_insa_gunlugu WHERE adim LIKE 'IKI\_IS%' ORDER BY adim;
