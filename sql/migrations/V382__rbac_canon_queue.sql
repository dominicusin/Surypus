-- V382__rbac_canon_queue.sql
-- Canonicalization task queue: allow decoupled background processing
CREATE TABLE IF NOT EXISTS rbac.canon_queue (
  id BIGSERIAL PRIMARY KEY,
  table_schema TEXT NOT NULL,
  table_name TEXT NOT NULL,
  enqueued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'pending', -- pending, in_progress, completed, failed
  batch_size INT NOT NULL DEFAULT 100,
  updated_count INT,
  error_message TEXT
);

CREATE OR REPLACE FUNCTION rbac.enqueue_canon_table(_schema TEXT, _table TEXT) RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.canon_queue (table_schema, table_name, enqueued_at, status, batch_size) VALUES (
    _schema, _table, NOW(), 'pending', (SELECT COALESCE(value::int,100) FROM rbac.config WHERE key='canonical_batch_size' LIMIT 1)
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac.dequeue_canon_batch(_limit INT) RETURNS TABLE (id BIGINT, schema_name TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT id, table_schema, table_name
  FROM rbac.canon_queue
  WHERE status = 'pending'
  ORDER BY enqueued_at ASC
  FOR UPDATE SKIP LOCKED
  LIMIT COALESCE(_limit, 10);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac.process_canon_queue_batch(_limit INT) RETURNS INT AS $$
DECLARE
  rec RECORD;
  updated INTEGER := 0;
BEGIN
  FOR rec IN SELECT id, schema_name, table_name FROM rbac.dequeue_canon_batch(_limit) LOOP
    BEGIN
      -- canonicalize a single table; ignore actual updated_count for simplicity here
      PERFORM rbac.canonicalize_table(rec.schema_name, rec.table_name);
      UPDATE rbac.canon_queue SET status = 'completed', updated_count = 0 WHERE id = rec.id;
      updated := updated + 1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE rbac.canon_queue SET status = 'failed', error_message = SQLERRM WHERE id = rec.id;
      updated := updated + 1;
    END;
  END LOOP;
  RETURN updated;
END;
$$ LANGUAGE plpgsql;
