-- Index: latest event per tenant
CREATE INDEX IF NOT EXISTS idx_event_store_tenant_latest
ON event_store (tenant_id, created_at DESC);
