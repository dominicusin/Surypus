-- Tenant query optimization indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_aggregates_tenant_updated
ON aggregates(tenant_id, updated_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_types_aggregate
ON event_types(aggregate_type, event_type);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_snapshots_tenant
ON aggregate_snapshots(tenant_id, aggregate_id, aggregate_version DESC);

-- Composite index for tenant + time-based queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_tenant_time
ON event_store(tenant_id, created_at DESC, event_type);