-- V424__rbac_backlog_metrics_json.sql
-- Export backlog metrics as JSON
CREATE OR REPLACE FUNCTION rbac.backlog_metrics_json() RETURNS JSONB AS $$
DECLARE
  rec RECORD;
  arr JSONB := '[]'::JSONB;
BEGIN
  FOR rec IN (
    SELECT table_schema, table_name, COUNT(*) AS backlog
    FROM rbac.canon_queue
    WHERE status = 'pending'
    GROUP BY table_schema, table_name
  ) LOOP
    arr := arr || jsonb_build_object('schema', rec.table_schema, 'table', rec.table_name, 'backlog', rec.backlog);
  END LOOP;
  RETURN arr;
END;
$$ LANGUAGE plpgsql;
