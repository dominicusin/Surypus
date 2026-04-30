-- Event store index enhancements for read-path optimizations
DO $$ BEGIN
  -- Tenant- and time-based queries
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_tenant_created
  ON event_store (tenant_id, created_at DESC);

  -- Aggregate+time based access
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_aggregate_created
  ON event_store (aggregate_id, created_at DESC);
END $$;
