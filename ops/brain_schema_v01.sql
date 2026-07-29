-- NIFDU Brain schema v0.1 (apply when ready)
-- NOTE: pgvector extension required later for embeddings.
-- CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS brain_sessions(
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  tenant        TEXT NOT NULL DEFAULT 'default',
  user_id       TEXT NOT NULL DEFAULT 'local',
  meta_json     TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS brain_events(
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  session_id    BIGINT REFERENCES brain_sessions(id),
  kind          TEXT NOT NULL,                 -- chat | codegen | compile | run | tool
  input_json    TEXT NOT NULL DEFAULT '{}',
  output_json   TEXT NOT NULL DEFAULT '{}',
  signals_json  TEXT NOT NULL DEFAULT '{}',    -- accepted/rejected/edit/compile_ok/etc
  redacted      BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS brain_feedback(
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_id      BIGINT REFERENCES brain_events(id),
  rating        INT NOT NULL DEFAULT 0,        -- -1/0/+1
  notes         TEXT NOT NULL DEFAULT '',
  meta_json     TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS brain_jobs(
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  kind          TEXT NOT NULL,                 -- embed | summarize | eval | train | sync
  status        TEXT NOT NULL DEFAULT 'queued',-- queued|running|done|fail
  payload_json  TEXT NOT NULL DEFAULT '{}',
  result_json   TEXT NOT NULL DEFAULT '{}',
  last_error    TEXT NOT NULL DEFAULT ''
);