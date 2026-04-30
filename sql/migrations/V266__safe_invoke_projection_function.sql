-- Safe invocation wrapper for projection handlers
CREATE OR REPLACE FUNCTION safe_invoke_function(
  p_func_name TEXT,
  p_event_data JSONB,
  p_aggregate_id UUID
) RETURNS VOID AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = p_func_name) THEN
    -- Try bridging first if available to standardize calls; fallback to direct dynamic SQL
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'projection_invoke_bridge') THEN
      PERFORM projection_invoke_bridge(p_func_name, p_event_data, p_aggregate_id);
    ELSE
      EXECUTE format('SELECT %I($1, $2)', p_func_name) USING p_event_data, p_aggregate_id;
    END IF;
  ELSE
    RAISE NOTICE 'Projection handler function % does not exist', p_func_name;
  END IF;
END;
$$ LANGUAGE plpgsql;
