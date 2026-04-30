-- V450__rbac_concurrency_benchmark.sql
-- Simple benchmark wrapper for concurrency by invoking batch and full canonicalization.
CREATE OR REPLACE FUNCTION rbac.run_concurrency_benchmark(_loops INTEGER DEFAULT 3, _batch INTEGER DEFAULT 10) RETURNS VOID AS $$
DECLARE
  i INTEGER := 0;
BEGIN
  WHILE i < COALESCE(_loops, 3) LOOP
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
      PERFORM rbac.canonicalize_all_batch(_batch);
    END IF;
    i := i + 1;
  END LOOP;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
  END IF;
END;
$$ LANGUAGE plpgsql;
