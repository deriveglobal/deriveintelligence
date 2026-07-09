-- ============================================================
-- Derive Intelligence — Teşvik Tablosuna Sezon Kolonu Ekleme
-- Date: 2026-06-15
-- Idempotent: IF NOT EXISTS / ON CONFLICT DO NOTHING
-- ============================================================
-- Mevcut veriler YAZ (summer) programına ait.
-- Bu migration: sezon kolonu ekler, eski unique constraint'i
-- sezon'u da kapsayacak şekilde günceller.
-- ============================================================

-- 1. sezon kolonu ekle (yoksa)
ALTER TABLE bi_tedarikci_tesvik
  ADD COLUMN IF NOT EXISTS sezon text NOT NULL DEFAULT 'YAZ'
  CHECK (sezon IN ('YAZ', 'KIŞ', 'DÖRT MEVSİM'));

-- 2. Mevcut satırları YAZ olarak işaretle (default zaten YAZ ama açıkça set et)
UPDATE bi_tedarikci_tesvik
SET sezon = 'YAZ'
WHERE sezon IS DISTINCT FROM 'YAZ'
  AND sezon NOT IN ('KIŞ', 'DÖRT MEVSİM');

-- 3. Eski unique constraint'i düşür (varsa)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bi_tedarikci_tesvik_tenant_marka_yil_segment_kanal_key'
      AND conrelid = 'bi_tedarikci_tesvik'::regclass
  ) THEN
    ALTER TABLE bi_tedarikci_tesvik
      DROP CONSTRAINT bi_tedarikci_tesvik_tenant_marka_yil_segment_kanal_key;
  END IF;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 4. Sezon dahil yeni unique constraint ekle (yoksa)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bi_tedarikci_tesvik_uq'
      AND conrelid = 'bi_tedarikci_tesvik'::regclass
  ) THEN
    ALTER TABLE bi_tedarikci_tesvik
      ADD CONSTRAINT bi_tedarikci_tesvik_uq
      UNIQUE (tenant_id, marka, yil, segment, kanal, sezon);
  END IF;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 5. sezon sütununa index
CREATE INDEX IF NOT EXISTS bi_tedarikci_tesvik_sezon_idx
  ON bi_tedarikci_tesvik (tenant_id, yil, sezon);

-- Verify
SELECT marka, sezon, COUNT(*) FROM bi_tedarikci_tesvik GROUP BY marka, sezon ORDER BY marka, sezon;
