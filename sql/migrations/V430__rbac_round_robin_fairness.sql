-- V430__rbac_round_robin_fairness.sql
-- Simple fairness metric to assess distribution of canonicalization work across tables
CREATE OR REPLACE FUNCTION rbac.compute_round_robin_fairness() RETURNS JSONB AS $$
DECLARE
  rec RECORD;
  total BIGINT := 0;
  max_backlog INT := 0;
  min_backlog INT := NULL;
  per_table JSONB := '[]'::JSONB;
BEGIN
  FOR rec IN (
    SELECT table_schema, table_name, COUNT(*) AS backlog
    FROM rbac.canon_queue
    WHERE status = 'pending'
    GROUP BY table_schema, table_name
  ) LOOP
    total := total + rec.backlog;
    per_table := per_table || jsonb_build_object('schema', rec.table_schema, 'table', rec.table_name, 'backlog', rec.backlog);
    IF rec.backlog > max_backlog THEN
      max_backlog := rec.backlog;
    END IF;
    IF min_backlog IS NULL OR rec.backlog < min_backlog THEN
      min_backlog := rec.backlog;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('total_backlog', total, 'max_backlog', max_backlog, 'min_backlog', min_backlog, 'per_table', per_table);
END;
$$ LANGUAGE plpgsql;
