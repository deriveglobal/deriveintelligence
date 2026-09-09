-- ============================================================
-- saha_satis_skor — rep "Portföyüm" segment skoru (BG/NBD çıktısı)
-- Gecelik Python işi (portfoyum_skor.py) doldurur; endpoint LEFT JOIN okur.
-- Sabit gün eşiği YOK — segment her müşterinin kendi geçmişinden (p_alive + kendi kadansı).
-- Idempotent. Fatih çalıştırır (psql). Fingerprint: fp_portfoyum_skor.sql.
-- ============================================================
CREATE TABLE IF NOT EXISTS saha_satis_skor (
  tenant_id     uuid        NOT NULL,
  musteri_kodu  text        NOT NULL,
  segment       text,                       -- due / slip / ok / seyrek / dormant
  p_alive       numeric,                    -- BG/NBD aktif-olma olasılığı (0..1)
  exp30         numeric,                    -- beklenen sipariş / 30 gün
  siparis       integer,                    -- ayrı sipariş günü sayısı (purchase occasion)
  son_gun       integer,                    -- son siparişten bu yana gün
  medyan_gun    integer,                    -- kendi siparişleri arası medyan gün
  hesaplandi_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, musteri_kodu)
);
CREATE INDEX IF NOT EXISTS ix_saha_satis_skor_seg ON saha_satis_skor (tenant_id, segment);

-- doğrula
SELECT 'saha_satis_skor' AS tablo,
       (SELECT count(*) FROM information_schema.columns WHERE table_name='saha_satis_skor') AS kolon_sayisi;
