-- V365__rbac_concurrency_nested_savepoints.sql
-- Nested savepoints to canonicalize a single table with per-table rollback
CREATE OR REPLACE FUNCTION rbac.canonicalize_table_with_savepoint(p_schema TEXT, p_table TEXT)
RETURNS INTEGER AS $$
DECLARE
  v_updated INTEGER := 0;
  v_sp TEXT;
  v_sql TEXT;
BEGIN
  v_sp := format('canon_%s_%s', p_schema, p_table);
  EXECUTE format('SAVEPOINT %I', v_sp);
  BEGIN
    v_sql := format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL', p_schema, p_table);
    EXECUTE v_sql;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE format('ROLLBACK TO SAVEPOINT %I', v_sp);
    RAISE;
  END;
  EXECUTE format('RELEASE SAVEPOINT %I', v_sp);
  RETURN v_updated;
END;
$$ LANGUAGE plpgsql;
