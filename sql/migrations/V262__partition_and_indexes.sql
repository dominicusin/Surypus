-- Partition and index tuning for event_store and projections
-- This migration adds a placeholder default partition and a couple of
-- defensive indexes to improve performance on hot paths.

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

-- Additional index improvements for high-traffic tables
CREATE INDEX IF NOT EXISTS idx_event_store_tenant_event ON event_store (tenant_id, event_type, created_at);
CREATE INDEX IF NOT EXISTS idx_projections_tenant_last ON projections (tenant_id, last_sequence);
CREATE INDEX IF NOT EXISTS idx_projection_handlers_event ON projection_handlers (projection_id, event_type);
