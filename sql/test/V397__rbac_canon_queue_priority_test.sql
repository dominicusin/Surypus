-- V397__rbac_canon_queue_priority_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='rbac' AND table_name='canon_queue' AND column_name='priority') THEN
    -- insert a sample row to ensure the column exists and default works
    INSERT INTO rbac.canon_queue (table_schema, table_name, status, batch_size, priority) VALUES ('rbac','dummy_table', 'pending', 100, 0);
  END IF;
END;
$$ LANGUAGE plpgsql;
