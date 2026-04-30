-- V335__rbac_circuit_breaker_reset_test.sql
-- Test circuit breaker reset function
DO $$
DECLARE
  v_state TEXT;
  v_failure_count INTEGER;
BEGIN
  -- First, trip the circuit breaker by recording failures
  PERFORM rbac.update_canon_circuit_breaker(FALSE);
  PERFORM rbac.update_canon_circuit_breaker(FALSE);
  PERFORM rbac.update_canon_circuit_breaker(FALSE);
  PERFORM rbac.update_canon_circuit_breaker(FALSE);
  PERFORM rbac.update_canon_circuit_breaker(FALSE); -- 5 failures should trip it assuming threshold=5

  -- Check that it's open
  SELECT state, failure_count INTO v_state, v_failure_count
  FROM rbac.canon_circuit_breaker WHERE id = 1;
  IF v_state <> 'OPEN' THEN
    RAISE EXCEPTION 'Expected circuit breaker OPEN after 5 failures, got %', v_state;
  END IF;

  -- Now reset it
  PERFORM rbac.reset_canon_circuit_breaker();

  -- Check that it's closed again
  SELECT state, failure_count INTO v_state, v_failure_count
  FROM rbac.canon_circuit_breaker WHERE id = 1;
  IF v_state <> 'CLOSED' THEN
    RAISE EXCEPTION 'Expected circuit breaker CLOSED after reset, got %', v_state;
  END IF;
  IF v_failure_count <> 0 THEN
    RAISE EXCEPTION 'Expected failure_count 0 after reset, got %', v_failure_count;
  END IF;
END;
$$ LANGUAGE plpgsql;