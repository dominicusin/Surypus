-- V348__rbac_concurrency_stress_scenarios.sql
-- Skeleton heavy-load concurrent canonicalization scenarios (to be run in CI with parallel sessions)
DO $$
BEGIN
  -- Enqueue minimal set for stress pattern
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'enqueue_canon_table') THEN
    PERFORM rbac.enqueue_canon_table('rbac','canon_metrics');
    PERFORM rbac.enqueue_canon_table('rbac','canon_events');
  END IF;
  -- Run a short batch and a full run to exercise concurrency paths
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
    PERFORM rbac.canonicalize_all_batch(10);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
  END IF;
END;
$$ LANGUAGE plpgsql;
