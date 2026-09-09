-- ============================================================================
-- bi_insa_gunlugu — 23 Tem 2026: SAHA HARITA KOKPITI (Faz 1 + 2a)
-- Kural 4 ayak izi. detay = jsonb. Sunucuda:
--   set -a; . ./.env; set +a; export PW="$POSTGRES_PASSWORD"
--   docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
--     psql -U assessment_app -d assessment_platform -f - < insa_gunlugu_harita.sql
-- ============================================================================

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('SAHA_HARITA_KOKPITI',
   'Saha Harita: kırık statik il-choropleth yerine gerçek interaktif harita (Leaflet+OSM) + tip-renkli müşteri pinleri + tam ekran + pin metrikleri.',
   'Fatih: statik il haritası çalışmıyordu ve tek tek müşteri pinlemeye uygun değildi; gerçek (Google gibi) zoom/pan harita + gerçek koordinatlı müşteri pinleri istendi. Tüketici/Ticari farklı renk, sorunlu müşteri yanıp sönsün, hem şehir hem müşteri bazında metrik + AI.',
   'FAZ 1: server HARITA_CSP_V1 (CSP''ye cdnjs + tile.openstreetmap.org eklendi) + HARITA_MUSTERI_V1/V2 (GET /api/saha/harita-musteriler; V2 koordinatı saha_musteri.lat''tan VEYA son ziyaret checkin_lat''tan alır → sahada check-in yapılmış tüm müşteriler haritada). saha.js HARITA_LEAFLET_V1 (Leaflet 1.9.4 cdnjs, OSM tile, tip-renkli circleMarker: Tüketici #0ea5e9 / Ticari #f59e0b, sorunlu=PASIF/ESKI/RISKLI yanıp söner haritaPinPulse, pine dokun balon + yol tarifi, fitBounds, legend; eski choropleth kontrolleri kaldırıldı, ensureLeaflet CDN loader). HARITA_TAMEKRAN_V1 (⛶ tam ekran). FAZ 2a: server HARITA_MUSTERI_OZET_V1 (GET /api/saha/harita-musteri-ozet?id= → ziyaret, teklif win/loss, satış adet/ciro 12ay, musteri_kodu) + saha.js HARITA_PIN_OZET_V1 (pine dokun→balonda metrikler + /api/bi/musteri-skor ile puan). AÇIK: Faz 2b (🤖 AI ziyaret özeti), Faz 3 (il seçici + şehir metrikleri + şehir AI). Detay: claude/derive-harita-kokpiti.md. Sadece server_container.mjs + shells/saha.js; migration yok.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim);

SELECT adim, LEFT(ne, 60) AS ne, ts::date FROM bi_insa_gunlugu WHERE adim = 'SAHA_HARITA_KOKPITI';
