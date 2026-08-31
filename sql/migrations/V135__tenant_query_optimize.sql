-- Tenant query optimization indexes
CREATE INDEX IF NOT EXISTS idx_aggregates_tenant_updated
ON aggregates(tenant_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_event_types_aggregate
ON event_types(aggregate_type, event_type);

-- aggregate_snapshots has no tenant_id column; index the columns it does have.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'aggregate_snapshots') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_snapshots_tenant ON aggregate_snapshots(aggregate_id, aggregate_version DESC)';
  END IF;
END $$;

-- Composite index for tenant + time-based queries
CREATE INDEX IF NOT EXISTS idx_event_store_tenant_time
ON event_store(tenant_id, created_at DESC, event_type);
