-- V353__rbac_self_heal_advanced.sql
-- Advanced self-healing for canonicalization with circuit breaker awareness
CREATE OR REPLACE FUNCTION rbac.self_heal_advanced() RETURNS VOID AS $$
DECLARE
  v_health JSONB;
  v_consistent BOOLEAN;
  v_cb_state VARCHAR(20);
BEGIN
  -- Inspect detailed health
  v_health := rbac.canon_health_detailed();
  v_consistent := (v_health ->> 'consistent')::BOOLEAN;
  v_cb_state := (v_health -> 'circuit_breaker' ->> 'state')::TEXT;

  -- If already healthy, nothing to do
  IF v_consistent THEN
    RAISE NOTICE 'Self-heal: already healthy';
    RETURN;
  END IF;

  -- If circuit breaker is OPEN, do not heal automatically
  IF v_cb_state = 'OPEN' THEN
    RAISE NOTICE 'Self-heal: circuit breaker OPEN, skipping self-heal';
    RETURN;
  END IF;

  -- Otherwise, trigger canonicalization; canonicalize_all() handles locking and logging
  PERFORM rbac.canonicalize_all();
END;
$$ LANGUAGE plpgsql;
