-- -- FRAMEWORK ENGINE MIGRATION ----------------
-- Adds multi-framework support to Derive.
-- Purely additive. No existing tables modified
-- except adding nullable bank_id to questions.
-- KRB data unaffected -- existing questions
-- have bank_id NULL and remain fully functional.

-- Ensure pgcrypto available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -- TABLE 1: frameworks -----------------------
CREATE TABLE IF NOT EXISTS frameworks (
  id UUID PRIMARY KEY
    DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  industry VARCHAR(255) NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  status VARCHAR(50) NOT NULL DEFAULT 'draft'
    CHECK (status IN (
      'draft', 'active', 'archived')),
  description TEXT,
  created_by UUID REFERENCES users(id)
    ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL
    DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL
    DEFAULT NOW(),
  UNIQUE(name, version)
);

CREATE INDEX IF NOT EXISTS
  idx_frameworks_status
  ON frameworks(status);

CREATE INDEX IF NOT EXISTS
  idx_frameworks_industry
  ON frameworks(industry);

-- -- TABLE 2: framework_question_banks ---------
-- One bank per stakeholder role per framework.
-- Links to existing stakeholder_roles table.
CREATE TABLE IF NOT EXISTS
  framework_question_banks (
  id UUID PRIMARY KEY
    DEFAULT gen_random_uuid(),
  framework_id UUID NOT NULL
    REFERENCES frameworks(id)
    ON DELETE CASCADE,
  role_key VARCHAR(100) NOT NULL,
  role_name VARCHAR(255) NOT NULL,
  stakeholder_group VARCHAR(255),
  stakeholder_group_id TEXT
    REFERENCES stakeholder_groups(id)
    ON DELETE SET NULL,
  requirement VARCHAR(50) NOT NULL
    DEFAULT 'optional'
    CHECK (requirement IN (
      'required',
      'recommended',
      'optional')),
  description TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  status VARCHAR(50) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active')),
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL
    DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL
    DEFAULT NOW(),
  UNIQUE(framework_id, role_key)
);

CREATE INDEX IF NOT EXISTS
  idx_framework_banks_framework
  ON framework_question_banks(framework_id);

CREATE INDEX IF NOT EXISTS
  idx_framework_banks_status
  ON framework_question_banks(
    framework_id, status);

-- -- TABLE 3: framework_kpis -------------------
-- KPI expectations per domain per framework.
-- domain_name stored directly --
-- not FK to business_domains table
-- because framework domains may differ
-- from the legacy taxonomy.
CREATE TABLE IF NOT EXISTS framework_kpis (
  id UUID PRIMARY KEY
    DEFAULT gen_random_uuid(),
  framework_id UUID NOT NULL
    REFERENCES frameworks(id)
    ON DELETE CASCADE,
  domain_name VARCHAR(255) NOT NULL,
  kpi_name VARCHAR(255) NOT NULL,
  kpi_description TEXT,
  expectation_type VARCHAR(50) NOT NULL
    DEFAULT 'tracked'
    CHECK (expectation_type IN (
      'tracked',
      'benchmarked')),
  target_value NUMERIC,
  target_unit VARCHAR(50),
  target_min NUMERIC,
  target_max NUMERIC,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL
    DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
  idx_framework_kpis_framework
  ON framework_kpis(framework_id);

CREATE INDEX IF NOT EXISTS
  idx_framework_kpis_domain
  ON framework_kpis(framework_id, domain_name);

-- -- COLUMN ADDITION: questions.bank_id --------
-- Links new framework questions to their bank.
-- Nullable -- existing KRB questions have
-- bank_id NULL and are completely unaffected.
ALTER TABLE questions
  ADD COLUMN IF NOT EXISTS
  bank_id UUID REFERENCES
    framework_question_banks(id)
    ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS
  idx_questions_bank_id
  ON questions(bank_id)
  WHERE bank_id IS NOT NULL;

-- -- END FRAMEWORK ENGINE MIGRATION ------------
