-- Ensure partitions exist for all tenants currently present in event_store
DO $$ BEGIN
  FOR r IN (SELECT DISTINCT tenant_id FROM event_store) LOOP
    IF r.tenant_id IS NOT NULL THEN
      PERFORM tenant_create_partition(r.tenant_id);
    END IF;
  END LOOP;
END $$ LANGUAGE plpgsql;
