-- V316__rbac_canonical_finalization_count_inconsistencies.sql
-- Provide a function that counts remaining canonicalization inconsistencies
CREATE OR REPLACE FUNCTION rbac.count_canon_inconsistencies() RETURNS INTEGER AS $$
DECLARE
  total INTEGER := 0;
  cnt INTEGER;
  rec RECORD;
BEGIN
  FOR rec IN (
    SELECT table_schema, table_name
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY table_schema, table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE path IS NOT NULL AND (canonical_path IS NULL OR canonical_path <> path)', rec.table_schema, rec.table_name) INTO cnt;
    total := total + COALESCE(cnt,0);
  END LOOP;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    EXECUTE 'SELECT COUNT(*) FROM rbac.wrapper WHERE path IS NOT NULL AND (canonical_path IS NULL OR canonical_path <> path)' INTO cnt;
    total := total + COALESCE(cnt,0);
  END IF;

  RETURN total;
END;
$$ LANGUAGE plpgsql;
