-- V335__rbac_circuit_breaker_reset.sql
-- Function to manually reset the canonicalization circuit breaker
CREATE OR REPLACE FUNCTION rbac.reset_canon_circuit_breaker()
RETURNS VOID AS $$
BEGIN
  UPDATE rbac.canon_circuit_breaker
  SET state = 'CLOSED',
      failure_count = 0,
      last_failure_time = NULL,
      next_attempt_time = NULL,
      half_open_calls = 0
  WHERE id = 1;
  
  RAISE NOTICE 'rbac circuit breaker manually reset to CLOSED state';
END;
$$ LANGUAGE plpgsql;