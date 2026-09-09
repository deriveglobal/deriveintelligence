-- bi_insa_gunlugu — KOKPIT2 ayak izi. ⚠⚠ YALNIZCA CUTOVER'DAN SONRA (kokpit2 canlıya alındıktan sonra) çalıştır.
-- Önizlemede iken çalıştırma — assistant'lara yanlış "canlı" bilgisi verir. Idempotent (WHERE NOT EXISTS).
-- Çalıştırma: docker exec -i krb-assessment-postgres psql -U <user> -d <db> < insa_gunlugu_kokpit2_final.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'KOKPIT2',
  'Komple yeni Finans Kokpiti canlıya alındı (kokpit2 → kokpit). Patron-önce tasarım; numaralı bölümler, dürüst DSO 3-yüz uzlaşımı, entegre AI okuması, kırılım-içi AI içgörü, tıklanır Performans marka drilldown.',
  'Eski kokpit yoğun/CFO-dili ve zaman-seçici tutarsızlığı + 3 çelişkili DSO içeriyordu. Kokpit YALNIZCA patron için sadeleştirildi (param iyi mi / sorun kimde / ne yapmalıyım). Çalışan tüm render/endpoint korundu; kabuk + tasarım + KPI yeniden yazıldı.',
  jsonb_build_object('yuzey','shells/kokpit.html (eski .bak.<ts> saklandı; geri dönüş kopyala+rebuild)','onizleme_route','/api/bi/kokpit2 (paralel kaldı)','tasarim','Space Grotesk, --accent #2fd6b0, numaralı bölümler'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KOKPIT2');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'KOKPIT2_NAKIT_PATRON',
  'Nakit & Tahsilat bölümü patron-önce: üstte düz-dil tek-satır hüküm (tahsilat sağlıklı ama X gecikmiş, %Y ilk 2 hesapta, yıllık ~Z finansman yükü), STAR "kim taşıyor", üç DSO yüzü açılır detaya indirildi, veri tazeliği damgası eklendi.',
  'Patron 3 farklı gün sayısından ("30 mu 134 mü") kafası karışıyordu ve yoğunlaşma % hatası vardı. Teknik detay başlık değil, opsiyonel açılır oldu. %yoğunlaşma gerçek net alacağa göre düzeltildi (eski hesap top-5 alt kümesine göreydi, ~%72 yanlış → gerçek ~%50/%38).',
  jsonb_build_object('endpoint_yeni','GET /api/bi/tahsilat-ozet (bi_tahsilat portföy ölçülen tahsilat süresi + geç oran)','tazelik','/api/bi/yukle/durum damgası','dogruluk','verify_nakit.sql ile kaynak doğrulanabilir'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KOKPIT2_NAKIT_PATRON');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'KOKPIT2_BOLUM_ICGORU',
  'Kokpit kırılım kartlarına (Satış Kanalı / Segment / Marka / Sezon) bölüm-başına AI tek-satır içgörü + odak trend sparkline eklendi.',
  'Her bölüm kendini açıklasın; "ne değişti & neden" tek bakışta görünsün. Doğrulanmış sayılar SQL''de hesaplanır, Claude yalnız doğal cümle kurar (uydurma yasak); LLM düşerse deterministik yedek.',
  jsonb_build_object('endpoint','GET /api/bi/bolum-icgoru','cache','bi_bolum_icgoru (tenant,gun) günlük','model','claude-sonnet-4-6','ek_endpoint','GET /api/bi/marka-kirilim?from= (Performans kartı marka drilldown, döneme uyar)'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KOKPIT2_BOLUM_ICGORU');

SELECT adim, LEFT(ne,60) ne, ts::date FROM bi_insa_gunlugu WHERE adim LIKE 'KOKPIT2%' ORDER BY adim;
