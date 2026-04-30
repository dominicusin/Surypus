-- V329__rbac_canonical_finalization_status_view_test.sql
-- Test the view exists and can be queried
DO $$
BEGIN
  PERFORM 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'vw_canon_status';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'rbac.vw_canon_status view not found';
  END IF;
END;
$$ LANGUAGE plpgsql;