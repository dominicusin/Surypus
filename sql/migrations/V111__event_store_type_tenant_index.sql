-- Additional index to optimize per-tenant per-type queries on event_store
CREATE INDEX IF NOT EXISTS idx_event_store_type_tenant
ON event_store (event_type, tenant_id, created_at DESC);
