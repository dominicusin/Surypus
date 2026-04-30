-- V392__rbac_concurrency_stress_runner.sql
-- Enqueue N canonicalization tasks to stress queue-based processing
CREATE OR REPLACE FUNCTION rbac.enqueue_multiple_can_tables(_n INTEGER DEFAULT 50) RETURNS VOID AS $$
DECLARE
  i INTEGER := 0;
  rec RECORD;
BEGIN
  IF _n IS NULL THEN _n := 50; END IF;
  FOR rec IN SELECT table_schema, table_name FROM rbac.list_can_path_tables() LOOP
    EXIT WHEN i >= _n;
    INSERT INTO rbac.canon_queue (table_schema, table_name, enqueued_at, status, batch_size)
    VALUES (rec.table_schema, rec.table_name, NOW(), 'pending', (SELECT COALESCE(value::int,100) FROM rbac.config WHERE key = 'canonical_batch_size' LIMIT 1));
    i := i + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
