-- Test: verify partition creation for a specific tenant_id
DO $$
DECLARE
  v_t UUID := '12345678-1234-1234-1234-1234567890ab'::UUID;
  v_part_name TEXT;
BEGIN
  PERFORM tenant_create_partition(v_t);
  v_part_name := 'event_store_' || replace(v_t::TEXT, '-', '_');
  IF EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = v_part_name) THEN
    RAISE NOTICE 'Partition % exists as expected', v_part_name;
  ELSE
    RAISE EXCEPTION 'Partition % not created', v_part_name;
  END IF;
END;
$$ LANGUAGE PLpgsql;
