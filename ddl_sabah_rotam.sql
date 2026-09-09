-- SABAH_ROTAM_V1 — tablolar (idempotent)
-- Rep başlangıç noktası (rep başına tek satır; öner-onayla / check-in / haritadan seç ile yazılır)
CREATE TABLE IF NOT EXISTS saha_rep_baslangic (
  tenant_id   uuid NOT NULL,
  rep_id      uuid NOT NULL,
  lat         double precision,
  lng         double precision,
  ad          text,
  kaynak      text,           -- 'oneri_kabul' | 'checkin' | 'harita'
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, rep_id)
);

-- Rota öneri günlüğü (öğrenme için — her sabah önerilen duraklar; gerçekleşenle karşılaştırılacak)
CREATE TABLE IF NOT EXISTS saha_rota_log (
  id           bigserial PRIMARY KEY,
  tenant_id    uuid NOT NULL,
  rep_id       uuid NOT NULL,
  gun          date NOT NULL,
  musteri_id   uuid NOT NULL,
  skor         numeric,
  sira         int,
  commit_mi    boolean DEFAULT false,   -- söz/plan mı yoksa AI önerisi mi
  onerildi_ts  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, rep_id, gun, musteri_id)
);
CREATE INDEX IF NOT EXISTS idx_rota_log_rep_gun ON saha_rota_log (tenant_id, rep_id, gun);
