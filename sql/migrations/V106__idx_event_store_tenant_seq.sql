-- Index to speed up tenant-scoped event retrieval by sequence
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_tenant_seq
ON event_store (tenant_id, sequence_number);
