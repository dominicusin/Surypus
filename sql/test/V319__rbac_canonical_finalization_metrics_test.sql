-- V319__rbac_canonical_finalization_metrics_test.sql
-- Test logging a canonicalization metric entry
DO $$
DECLARE
  cnt INTEGER;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_canon_metrics') THEN
    PERFORM rbac.log_canon_metrics(5, '{"sample":"data"}'::jsonb);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_metrics') THEN
    SELECT COUNT(*) INTO cnt FROM rbac.canon_metrics WHERE updated_rows = 5;
    IF cnt = 0 THEN
      RAISE EXCEPTION 'RBAC metrics log entry not found';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
