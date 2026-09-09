-- ============================================================================
-- bi_insa_gunlugu — 23 Tem 2026: SAHA SCROLL / ÇEK-YENİLE düzeltmesi + ⟳ buton
-- Kural 4 ayak izi. detay = jsonb. Sunucuda calistir:
--   set -a; . ./.env; set +a; export PW="$POSTGRES_PASSWORD"
--   docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
--     psql -U assessment_app -d assessment_platform -f - < insa_gunlugu_scroll.sql
-- (idempotent: ayni adim varsa yeniden eklemez)
-- ============================================================================

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('SAHA_CEKYENILE_KALDIR',
   'Saha çek-yenile (pull-to-refresh) kaldırıldı + üst bara ⟳ yenile butonu eklendi.',
   'Saha temsilcisi Eftal Yıldız hata bildirimi ("Scroll hassasiyeti"): en üstteyken parmak ~64px aşağı çekilince kazara "Yenileniyor" tetikleniyor ve takılıyordu. Fatih kararı: iPhone gibi — çek-yenile hiç olmasın, yerine kasıtlı buton.',
   'Kök neden: özel JS bileşeni PULL_REFRESH_V1 (TH=64px, hız/niyet kontrolü yok). overscroll-behavior CSS (PTR_FIX_V1/V2) bu JS bileşenini etkilemiyordu → asıl fix PTR_DISABLE_V1: PULL_REFRESH_V1 IIFE ilk satırına koşulsuz return, hiçbir touch dinleyicisi bağlanmaz. Yerine SAHA_YENILE_V1: saha üst barına (çıkış ikonu solu) ⟳ butonu — dokununca aktif oda/görünümü yeniden yükler (eski PTR mantığı: aktif sekme/oda click), 360° dönüş geri bildirimi. Global, kazara tetiklenmez. Sadece shells/saha.js; migration yok. Not: app canlı içeriği yüklediği için Android + iOS (TestFlight) otomatik aldı, APK/rebuild gerekmedi.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (
  SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim
);

SELECT adim, LEFT(ne, 60) AS ne, ts::date FROM bi_insa_gunlugu
WHERE adim = 'SAHA_CEKYENILE_KALDIR';
