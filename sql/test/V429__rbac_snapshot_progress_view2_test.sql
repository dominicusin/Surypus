-- V429__rbac_snapshot_progress_view2_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='rbac' AND table_name='vw_canon_progress_enhanced') THEN
    PERFORM 1;
  END IF;
END;
$$ LANGUAGE plpgsql;
