DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM event_store LIMIT 1) THEN
    PERFORM tenant_create_partition((SELECT tenant_id FROM event_store LIMIT 1));
  END IF;
END $$;
