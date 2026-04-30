-- V311__rbac_canonical_finalization_indexes.sql
-- Create helpful indexes for RBAC canonicalization tables
DO $$
DECLARE
  t RECORD;
  idx_sql TEXT;
BEGIN
  FOR t IN (
    SELECT table_schema, table_name
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY table_schema, table_name
  ) LOOP
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_%I_can_path ON %I.%I (canonical_path)', t.table_schema, t.table_name, t.table_schema, t.table_name);
  END LOOP;
END;
$$ LANGUAGE plpgsql;
