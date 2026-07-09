create table if not exists participant_upload_batches (
  upload_batch_id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  company_id uuid not null references assessment_projects(id) on delete cascade,
  uploaded_by uuid references users(id) on delete set null,
  filename text,
  status text not null default 'previewed',
  preview_json jsonb not null default '{}',
  created_at timestamptz not null default now(),
  imported_at timestamptz
);

create index if not exists idx_participant_upload_batches_assessment on participant_upload_batches (assessment_id, created_at desc);
