-- Ensure all tenants have a dedicated event_store partition
DO $$ BEGIN
  FOR rec IN SELECT DISTINCT tenant_id FROM event_store LOOP
    IF rec.tenant_id IS NULL THEN
      CONTINUE;
    END IF;
    BEGIN
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS event_store_%s PARTITION OF event_store FOR VALUES IN (%L)',
        replace(rec.tenant_id::TEXT, '-', '_'), rec.tenant_id
      );
    EXCEPTION
      WHEN duplicate_table THEN NULL;
    END;
  END LOOP;
END $$ LANGUAGE plpgsql;
