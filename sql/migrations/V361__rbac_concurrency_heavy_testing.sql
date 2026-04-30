-- V361__rbac_concurrency_heavy_testing.sql
-- Heavy concurrency pattern scaffold: simulate multiple partial runs
CREATE OR REPLACE FUNCTION rbac.concurrent_batch_heavy_simulation(iterations INTEGER DEFAULT 5, batch_size INTEGER DEFAULT 100)
RETURNS VOID AS $$
DECLARE
  i INTEGER := 0;
BEGIN
  IF iterations < 1 THEN RETURN; END IF;
  WHILE i < iterations LOOP
    -- Attempt a single batch canonicalization; actual concurrency is exercised via CI runners
    PERFORM rbac.canonicalize_all_batch(batch_size);
    i := i + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
