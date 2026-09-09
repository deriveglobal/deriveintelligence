-- ARAC_YETKI_V1 — tool authorization matrix (user x tool). Run BEFORE deploy (değişmez #10).
CREATE TABLE IF NOT EXISTS bi_arac_yetki (
  id         bigserial PRIMARY KEY,
  tenant_id  uuid,
  user_id    uuid NOT NULL,
  arac_kod   text NOT NULL,
  aktif      boolean NOT NULL DEFAULT true,
  granted_by uuid,
  granted_at timestamptz DEFAULT now(),
  UNIQUE (tenant_id, user_id, arac_kod)
);
CREATE INDEX IF NOT EXISTS idx_arac_yetki_user ON bi_arac_yetki (tenant_id, user_id);
