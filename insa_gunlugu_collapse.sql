-- bi_insa_gunlugu — COLLAPSE_V1. ⚠ Canlıda çalıştığı görüldükten SONRA çalıştır.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'COLLAPSE_V1',
  'Kokpit: 🩸 Marj Alarmı ve 🎯 İyileştirme Hedefleri kartları katlanabilir yapıldı (başlığa tıkla → katlanır; tercih hatırlanır).',
  'İki ağır tablo dikey alanın çoğunu kaplıyor ve gezinmeyi zorlaştırıyordu; içerik aynı kalır (as-is) ama istenince katlanarak kokpit sadeleşir. Yeni cockpit''in artımlı inşasının 2. tuğlası (1. = NEDEN_V1).',
  jsonb_build_object('aciklama','Frontend-only (shells/kokpit.html): kartlara .collapsible + data-ck; initCollapse başlığa tıklama dinler, gövdeyi (h3 hariç) gizler, chevron ▾/▸ döner, tercih localStorage''da. Varsayılan AÇIK. node --check geçti. Geri alma: kokpit.html.bak.*'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='COLLAPSE_V1');
SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='COLLAPSE_V1';
