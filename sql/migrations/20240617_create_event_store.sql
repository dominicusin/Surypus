-- Phase 3: Event Store for ES (Accounts)
CREATE TABLE IF NOT EXISTS accounting_events (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('accounting_events_id_seq'),
  aggregate_type TEXT NOT NULL,
  aggregate_id BIGINT NOT NULL,
  event_type TEXT NOT NULL,
  event_data JSONB NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  version INT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_accounting_events_agg ON accounting_events (aggregate_type, aggregate_id, timestamp);
