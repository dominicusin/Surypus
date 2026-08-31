-- Add composite index on aggregate_snapshots for faster rebuilds.
-- Guarded: only index columns that exist on aggregate_snapshots.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'aggregate_snapshots') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_snapshots_aggregate_tenant ON aggregate_snapshots(aggregate_id, aggregate_version DESC)';
  END IF;
END $$;
