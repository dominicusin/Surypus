-- V359__rbac_canon_cb_history_view_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'vw_canon_cb_history') THEN
    PERFORM 1; -- view exists
  END IF;
END;
$$ LANGUAGE plpgsql;
