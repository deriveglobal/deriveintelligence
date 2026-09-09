-- ============================================================================
-- bi_insa_gunlugu — 22-23 Tem 2026 oturumu: AKILLI FIYATLANDIRMA + KRB KIYAS
-- Kural 4 (ayak izi) tamamlama. detay = jsonb.
-- Sunucuda calistir:
--   set -a; . ./.env; set +a; export PW="$POSTGRES_PASSWORD"
--   docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
--     psql -U assessment_app -d assessment_platform -f - < insa_gunlugu_smartprice.sql
-- (idempotent: ayni adim varsa yeniden eklemez)
-- ============================================================================

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('SMART_PRICING_MOTOR',
   'Kişiye özel akıllı fiyat motoru canlı (SMARTPRICE_V1/V2/V3): aynı SKU''ya müşteriye göre farklı önerilen fiyat.',
   'Fatih: aynı lastiği (ör. SAILUN 385/65R22.5) sadık/hızlı ödeyen müşteriye daha uygun, yavaş/riskli müşteriye daha yüksek öner — kârı artır.',
   'Müşteri Skoru (Ödeme %35 + Hacim %25 + Sadakat %20 + Risk %20, percentile). Fiyat = banda-yerleştirme (plBase=0.62*(1-s_vol)+0.38*(1-s_risk)) + yenileme-maliyeti taban (floorCost/(1-brand_hedef)) + vade-fiyat merdiveni (fairAt=pesin+floorCost*0.42/365*vade). Lift-and-hold: LIFT/HOLD/WATCH. Uç: /api/bi/musteri-skor + /api/bi/musteri-fiyat-liste. Yüzey: müşteri kartı (SMARTFIYAT_UI_V1/V2). Yetki: manager/admin + ERP-bağlı.'),

  ('MARJ_ALARM_MARKATIER',
   'SKU marj alarmı + markaya-özel hedef + desen kırılımı canlı (MARKATIER_V1, MARJDESEN_V1).',
   'Sabit %12 hedef yanlıştı: premium≠ince (Bridgestone %7.3 underpriced, Yokohama %21.5 sağlıklı). Her marka kendi kanıtlanmış seviyesine göre ölçülmeli.',
   'Hedef = GREATEST(0.12, LEAST(0.30, marka SKU-marj p60)). Sailun ~%26, Bridgestone %12 taban. Yenileme maliyeti = Σsatir_kdv_haric/Σmiktar (bi_tedarikci_faturalari son 90g). Maliyet-altı satır kırmızı. Satıra tıkla→desen (kalem_kodu) kırılımı. Kokpit "🩸 Marj Alarmı". Portföy sızıntısı: flat %12''de ₺34M/176 SKU → markaya-özel ₺43.9M/228 SKU (aspirasyonel üst-sınır).'),

  ('KRB_KIYAS_IYILESTIRME',
   'KRB Kıyas + İyileştirme Hedefleri canlı (SMARTKIYAS_V1/V2): hangi müşteri KRB ortalamasını düşürüyor.',
   'Fatih: hangi müşterilere iyileştirme yapmalıyız ki KRB metrikleri yükselsin — açıkça söylensin.',
   'Müşteri vs KRB ort. 4 metrik: tahsilat, marj, gecikme, büyüme. Kart verdict (müşteri kartı, SMARTKIYAS_CARD_UI_V1) + kokpit "🎯 İyileştirme Hedefleri" (marj kaybı ₺ sıralı, bayraklı). Uç: /api/bi/musteri-kiyas + /api/bi/iyilestirme-hedefleri. Hayalet-tedarikçi filtresi (TEDARFILT_V1): grup=TEDARİKÇİ VE 12ay ciro>5M hariç (SAILUN import entiteleri) — küçük gerçek müşteriler korunur. Vade 33→40 artefakt düzeltmesi.'),

  ('RAKIP_SAVUNMA',
   'Kişiye özel fiyata rakip savunma sinyali canlı (RAKIPWATCH_V1).',
   'Sahada müşteride kayıtlı rakip teklifi varsa öneri rakibi geçip anlaşmayı kaybettirmemeli, ama maliyet altına da inmemeli.',
   'saha_teklif''te (müşteri+ebat, son 9 ay) rakip_fiyat varsa: oneri=max(rakip, floorCost/0.88); durum=RAKIP (savun) veya RAKIP_MALIYET (taban). Müşteri kartında kırmızı "⚔ Rakip: marka fiyat · neden" satırı (RAKIPWATCH_UI_V1). Rakip yoksa mantık değişmez → kesme yalnız gerçek sinyalle.'),

  ('DOKUMANTASYON_TOOLTIP',
   'İlk-kullanıcı dokümantasyonu: uygulama-içi ⓘ ipuçları + yazılı rehber (TOOLTIP_KOKPIT_V1, TOOLTIP_SAHA_V1).',
   'Fatih: her kartı ilk kez gören biri için açıklama gerek — uygulama-içi tooltip.',
   'Kokpit: her kart başlığına ⓘ (DEFS/#pop hover). Müşteri kartı: .saha-help ⓘ dokun→toast (KRB Kıyas, Akıllı Fiyat, Finansal). İçerik: kart ne gösterir + ne yapmalı. Ayrıca DERIVE_KART_REHBERI.md yazılı onboarding kılavuzu (tüm kartlar, renk/etiket sözlüğü).'),

  ('VISIT_FULLEDIT',
   'Ziyaret Düzenle modalı artık TÜM ziyareti düzenliyor (ZIYARET_TAMDUZEN_V1 + ZIYARET_FOTO_SIL_V1).',
   'Saha temsilcisi (Eftal Yıldız, 17.07) talebi: düzenlemede raf payı/bayilik gibi tüm alanlar değiştirilebilmeli — eskiden yalnız tarih/katılımcı/not vardı.',
   'ziyaretDuzenleModal genişletildi: tip''e göre profil alanları (raf/bayilik/rakip/kış-yaz stok VEYA sektör/araç-parkı/marka/tedarikçi/potansiyel) z.detay''dan ön-dolu + fotoğraf ekle/sil. Kayıtta detay guncelle ucuna, profil müşteri ucuna (her zaman) yazılır. Yeni backend ucu DELETE /api/saha/ziyaretler/:zid/foto/:fid (sahip/manager kapılı). Nokta durumu hariç (ERP''den hesaplanır). Sadece saha.js + server; migration yok.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (
  SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim
);

-- Kontrol: bu oturumun girisleri
SELECT adim, LEFT(ne, 60) AS ne, ts::date FROM bi_insa_gunlugu
WHERE adim IN ('SMART_PRICING_MOTOR','MARJ_ALARM_MARKATIER','KRB_KIYAS_IYILESTIRME','RAKIP_SAVUNMA','DOKUMANTASYON_TOOLTIP','VISIT_FULLEDIT')
ORDER BY ts DESC;
