-- V341__rbac_canonical_finalize_table_patch.sql
-- Individual table patch to canonicalize one table and return affected rows
CREATE OR REPLACE FUNCTION rbac.canonicalize_table(p_schema TEXT, p_table TEXT)
RETURNS INTEGER AS $$
DECLARE
  cnt INTEGER := 0;
  dyn_sql TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = p_schema AND table_name = p_table AND column_name = 'path') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = p_schema AND table_name = p_table AND column_name = 'canonical_path') THEN
      dyn_sql := format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL', p_schema, p_table);
      EXECUTE dyn_sql;
      GET DIAGNOSTICS cnt = ROW_COUNT;
  END IF;
  END IF;
  RETURN COALESCE(cnt,0);
END;
$$ LANGUAGE plpgsql;
