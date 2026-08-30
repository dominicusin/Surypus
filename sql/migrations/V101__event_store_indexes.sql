-- Add missing indexes to improve event store query performance
CREATE INDEX IF NOT EXISTS idx_event_store_type_date
ON event_store (event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_store_tenant_type
ON event_store (tenant_id, event_type);
CREATE INDEX IF NOT EXISTS idx_event_store_tenant_seq
ON event_store (tenant_id, sequence_number);
