-- Simple automated snapshot policy scaffold
-- This migration introduces a helper function to create snapshots
-- after a configurable number of events for a given aggregate.
CREATE OR REPLACE FUNCTION maybe_create_snapshot(
  p_aggregate_id UUID,
  p_threshold INT DEFAULT 50
) RETURNS VOID AS $$
DECLARE
  v_event_count INT;
  v_version INT;
  v_state JSONB;
BEGIN
  -- Count events for this aggregate since beginning
  SELECT COUNT(*) INTO v_event_count FROM event_store WHERE aggregate_id = p_aggregate_id;
  IF v_event_count < p_threshold THEN
    RETURN;
  END IF;

  -- Determine latest version for the aggregate
  SELECT COALESCE(MAX(event_version), 0) INTO v_version FROM event_store WHERE aggregate_id = p_aggregate_id;

  -- Rebuild latest state if possible (Inventory aggregate in this scope)
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'inventory_rebuild') THEN
    v_state := inventory_rebuild(p_aggregate_id);
  ELSE
    v_state := '{}'::JSONB;
  END IF;

  -- Ensure non-null state
  IF v_state IS NULL THEN
    v_state := '{}'::JSONB;
  END IF;
  -- Persist snapshot
  PERFORM snapshot_create(p_aggregate_id, 'Inventory', v_version, v_state, v_event_count);
END;
$$ LANGUAGE plpgsql;
