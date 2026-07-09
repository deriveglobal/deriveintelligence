CREATE TABLE IF NOT EXISTS demo_requests (
  id UUID PRIMARY KEY
    DEFAULT gen_random_uuid(),
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  company_name VARCHAR(255) NOT NULL,
  company_size VARCHAR(50) NOT NULL,
  industry VARCHAR(255),
  message TEXT,
  status VARCHAR(50) NOT NULL
    DEFAULT 'new'
    CHECK (status IN (
      'new', 'contacted', 'converted',
      'declined')),
  ip_address VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL
    DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
  idx_demo_requests_status
  ON demo_requests(status);

CREATE INDEX IF NOT EXISTS
  idx_demo_requests_created
  ON demo_requests(created_at DESC);
