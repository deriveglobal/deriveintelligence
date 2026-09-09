-- bi_insa_gunlugu — NEDEN_V1: Kokpit Marka kırılımında "neden?" drill.
-- ⚠ YALNIZCA canlıya geçip tarayıcıda çalıştığı görüldükten SONRA çalıştır.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT 'NEDEN_V1',
  'Kokpit Marka kırılımında "neden?" drill: markaya tıkla → sebep_arastir_marj köprüsü (mix/fiyat/maliyet/değişim) + anlatı + öneri INLINE açılır.',
  'Sayılar tek başına "ne" der, "neden" demez. Mevcut sebep_arastir_marj motoru yalnızca CEO Assistant sohbetinde görünüyordu; kokpitte bir metriğin nedenini tek tıkla göstermek "hesap makinesi değil, anlıyor" hissini verir — sistemin ilk reasoning-layer yüzeyi.',
  jsonb_build_object('aciklama','Frontend-only (shells/kokpit.html): barCard Marka satırları tıklanabilir yapıldı + _nedenToggle → GET /api/bi/finans-marka-sebep (mevcut endpoint, YENİ backend yok). Köprü diverging bar (maliyet− kırmızı, fiyat/mix+ yeşil), güven rozeti (dürüst belirsizlik), saha_ipuclari varsa gösterilir. node --check geçti. Geri alma: shells/kokpit.html.bak.* geri kopyala + rebuild. Sıradaki: aynı drill segment + müşteri (sebep_arastir_musteri) için.'),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='NEDEN_V1');
SELECT adim, LEFT(ne,55) ne, ts::date FROM bi_insa_gunlugu WHERE adim='NEDEN_V1';
