-- Add composite index on aggregate_snapshots for faster rebuilds
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_snapshots_aggregate_tenant
ON aggregate_snapshots(aggregate_id, aggregate_version DESC, tenant_id);
