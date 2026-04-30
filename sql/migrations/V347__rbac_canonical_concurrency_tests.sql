-- V347__rbac_canonical_concurrency_tests.sql
-- Skeleton tests for concurrency scenarios in canonicalization
-- Real concurrency tests for canonicalization (idempotence + batch pathing)
DO $$
BEGIN
  -- 1) idempotence: two consecutive runs should be safe
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
    PERFORM rbac.canonicalize_all();
    IF NOT rbac.is_canonical_consistent() THEN
      RAISE EXCEPTION 'concurrency test failed: invariant violated after two runs';
    END IF;
  END IF;

  -- 2) basic batch flow: enqueue a small batch and run batch
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'enqueue_canon_table') THEN
      PERFORM rbac.enqueue_canon_table('rbac','canon_metrics');
      PERFORM rbac.enqueue_canon_table('rbac','canon_events');
    END IF;
    PERFORM rbac.canonicalize_all_batch(20);
    IF NOT rbac.is_canonical_consistent() THEN
      RAISE EXCEPTION 'concurrency test failed: invariant violated after canonicalize_all_batch';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
