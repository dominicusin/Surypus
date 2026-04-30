-- Ensure tenant-specific partitions for event_store and related tables
CREATE OR REPLACE FUNCTION ensure_event_store_partition(
  p_tenant_id UUID
) RETURNS VOID AS $$
DECLARE
  v_table_name TEXT;
  v_exists BOOLEAN;
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN;
  END IF;
  v_table_name := 'event_store_' || replace(p_tenant_id::TEXT, '-', '_');
  SELECT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = v_table_name AND n.nspname = 'public'
  ) INTO v_exists;
  IF NOT v_exists THEN
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF event_store FOR VALUES IN (%L)', v_table_name, p_tenant_id);
  END IF;
END;
$$ LANGUAGE plpgsql;
