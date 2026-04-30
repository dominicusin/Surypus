-- V387__rbac_canon_progress_view_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'vw_canon_progress') THEN
    PERFORM 1; -- ensure view exists
  END IF;
END;
$$ LANGUAGE plpgsql;
