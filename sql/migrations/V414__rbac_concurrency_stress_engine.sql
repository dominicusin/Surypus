-- V414__rbac_concurrency_stress_engine.sql
-- A small, deterministic stress engine that drives canonicalize_all in quick succession
CREATE OR REPLACE FUNCTION rbac.run_concurrency_stress(_cycles INTEGER DEFAULT 5, _delay_ms INTEGER DEFAULT 100) RETURNS VOID AS $$
DECLARE
  i INTEGER := 0;
BEGIN
  WHILE i < COALESCE(_cycles, 5) LOOP
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
      -- Optionally sleep to simulate real-world spacing
      IF _delay_ms > 0 THEN
        PERFORM pg_sleep(_delay_ms / 1000.0);
      END IF;
      PERFORM rbac.canonicalize_all();
    END IF;
    i := i + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
