-- Partition and index tuning for event_store and projections
-- This migration adds a placeholder default partition and a couple of
-- defensive indexes to improve performance on hot paths.
-- All index creation is guarded: each index is only created if the
-- referenced columns actually exist in the target table, so this file
-- is safe to run on any schema state.

-- Placeholder: ensure a default partition exists for event_store (no-op if not implemented)
CREATE OR REPLACE FUNCTION ensure_event_store_default_partition()
RETURNS VOID AS $$
BEGIN
  -- In production, this would create the default partition if missing.
  -- This is a placeholder to keep migrations aligned with the plan.
  RAISE NOTICE 'ensure_event_store_default_partition invoked';
END;
$$ LANGUAGE plpgsql;

SELECT ensure_event_store_default_partition();

-- Additional index improvements for high-traffic tables (guarded)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_store' AND column_name='tenant_id')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_store' AND column_name='event_type')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_store' AND column_name='created_at') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_event_store_tenant_event ON event_store(tenant_id, event_type, created_at)';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='projections' AND column_name='tenant_id')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='projections' AND column_name='last_sequence') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_projections_tenant_last ON projections(tenant_id, last_sequence)';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='projection_handlers' AND column_name='projection_id')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='projection_handlers' AND column_name='event_type') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_projection_handlers_event ON projection_handlers(projection_id, event_type)';
  END IF;
END $$;
