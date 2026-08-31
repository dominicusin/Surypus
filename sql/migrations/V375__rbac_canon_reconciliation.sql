-- V375__rbac_canon_reconciliation.sql
CREATE OR REPLACE FUNCTION rbac.get_canon_reconciliation() RETURNS JSONB AS $$
DECLARE
  rec RECORD;
  out JSONB := '[]'::JSONB;
  cnt INTEGER;
BEGIN
  FOR rec IN (
     SELECT c1.table_schema, c1.table_name
     FROM information_schema.columns c1
     JOIN information_schema.columns c2 ON c1.table_schema=c2.table_schema AND c1.table_name=c2.table_name
     WHERE c1.column_name='path' AND c2.column_name='canonical_path' AND c1.table_schema='rbac'
     GROUP BY c1.table_schema, c1.table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL', rec.table_schema, rec.table_name) INTO cnt;
    out := out || jsonb_build_object('schema', rec.table_schema, 'table', rec.table_name, 'missing', cnt);
  END LOOP;
  RETURN out;
END;
$$ LANGUAGE plpgsql;
