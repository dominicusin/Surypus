-- Composite index to speed up tenant/type/date queries on event_store
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_tenant_type_created_at
ON event_store (tenant_id, event_type, created_at DESC);
