-- V377__rbac_concurrency_stress_final.sql
-- Simple stress harness: repeatedly call canonicalize_all_batch to simulate load
CREATE OR REPLACE FUNCTION rbac.concurrency_stress_run(_iterations INTEGER DEFAULT 3, _batch_size INTEGER DEFAULT 50) RETURNS VOID AS $$
DECLARE
  i INTEGER := 0;
BEGIN
  IF _iterations IS NULL OR _iterations < 1 THEN
    _iterations := 1;
  END IF;
  IF _batch_size IS NULL OR _batch_size < 1 THEN
    _batch_size := 50;
  END IF;
  WHILE i < _iterations LOOP
    -- Run a single batch canonicalization; real concurrency requires multi-session CI
    PERFORM rbac.canonicalize_all_batch(_batch_size);
    i := i + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
