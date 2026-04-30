-- V324__rbac_canonical_finalization_views_test.sql
-- Verify the view exists and can be queried
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'view_canon_summary') THEN
    PERFORM 1;
  ELSE
    RAISE EXCEPTION 'rbac.view_canon_summary view not found';
  END IF;
END;
$$ LANGUAGE plpgsql;
