-- KAPSAM_AKSIYON_V1 — Saha rapor aksiyon/öğrenme kaydı (append-only, tam geçmiş).
-- Her satır aksiyonu buraya yazılır; hiçbir buton ölü değil. Rapor bu tabloyu okuyup
-- susturulanları eler, gerekçeleri yöneticiye gösterir, sinyal biriktirir.
-- Yeniden kullanılabilir: rapor kolonu ile Kapsam dışındaki tablolarda da kullanılır.

CREATE TABLE IF NOT EXISTS saha_musteri_aksiyon (
  id            BIGSERIAL PRIMARY KEY,
  tenant_id     UUID NOT NULL,
  musteri_id    UUID NOT NULL,
  rapor         TEXT NOT NULL DEFAULT 'kapsam',        -- kaynak rapor (yeniden kullanım)
  tur           TEXT NOT NULL,                          -- GITTIM|PLANLA|ILET|ATA|SUSTUR|GERI_AL|NOT
  aktor_id      UUID NOT NULL,                          -- aksiyonu yapan kullanıcı
  aktor_rol     TEXT,                                   -- rep|manager|admin (o anki)
  gerekce       TEXT,                                   -- SUSTUR için: KAPANDI|RAKIP|SEZON|PAS|YANLIS|DIGER
  gerekce_metin TEXT,                                   -- serbest metin (Diğer / ek açıklama) — yönetici görür
  hedef_rep     UUID,                                   -- ATA/ILET için hedef temsilci
  ziyaret_id    UUID,                                   -- GITTIM/PLANLA/ILET ürettiği ziyaret
  olusturma_ts  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- En son durum (susturulmuş mu?) hızlı çözümü için:
CREATE INDEX IF NOT EXISTS idx_sma_son
  ON saha_musteri_aksiyon (tenant_id, musteri_id, olusturma_ts DESC);
-- Yönetici "susturulanlar" paneli + sinyal toplama:
CREATE INDEX IF NOT EXISTS idx_sma_sustur
  ON saha_musteri_aksiyon (tenant_id, rapor, tur, olusturma_ts DESC);

-- NOT: "şu an susturulu" = bir müşterinin (tenant, rapor) için EN SON SUSTUR/GERI_AL
--      satırı SUSTUR ise. Rapor sorgusu DISTINCT ON ile bunu çözer; ayrı state tablosu yok.
