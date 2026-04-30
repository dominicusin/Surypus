-- Phase 6.3.1: maybe_create_snapshot helper to auto-create snapshots on demand
CREATE OR REPLACE FUNCTION maybe_create_snapshot(
  p_aggregate_id UUID,
  p_threshold INT
) RETURNS VOID AS $$
DECLARE
  v_latest_version INT;
  v_has_recent BOOLEAN;
BEGIN
  IF p_aggregate_id IS NULL THEN
    RETURN;
  END IF;
  SELECT aggregate_version INTO v_latest_version
  FROM aggregate_snapshots
  WHERE aggregate_id = p_aggregate_id
  ORDER BY aggregate_version DESC
  LIMIT 1;

  IF v_latest_version IS NULL THEN
    -- create initial snapshot if none exists
    PERFORM snapshot_create(p_aggregate_id, 'Inventory', 1, '{}'::JSONB, 0);
    RETURN;
  END IF;

  SELECT (v_latest_version >= p_threshold) INTO v_has_recent;
  IF v_has_recent THEN
    RETURN;
  END IF;

  -- create a new snapshot using current aggregate state snapshot (simplified)
  PERFORM snapshot_create(p_aggregate_id, 'Inventory', v_latest_version + 1, '{}'::JSONB, 0);
END;
$$ LANGUAGE plpgsql;
