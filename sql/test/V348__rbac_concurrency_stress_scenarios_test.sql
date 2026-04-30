-- V348__rbac_concurrency_stress_scenarios_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'enqueue_canon_table') THEN
    -- Try to enqueue a couple entries and trigger batch processing
    PERFORM rbac.enqueue_canon_table('rbac','canon_metrics');
    PERFORM rbac.enqueue_canon_table('rbac','canon_events');
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
    PERFORM rbac.canonicalize_all_batch(10);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
  END IF;
END;
$$ LANGUAGE plpgsql;
