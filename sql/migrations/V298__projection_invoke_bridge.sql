-- Phase 6.3: Projection invoke bridge to standardize calls
CREATE OR REPLACE FUNCTION projection_invoke_bridge(
  p_handler_name TEXT,
  p_event_data JSONB,
  p_aggregate_id UUID
) RETURNS VOID AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = p_handler_name) THEN
    EXECUTE format('SELECT %I($1, $2)', p_handler_name) USING p_event_data, p_aggregate_id;
  ELSE
    RAISE NOTICE 'Projection handler % does not exist', p_handler_name;
  END IF;
END;
$$ LANGUAGE plpgsql;
