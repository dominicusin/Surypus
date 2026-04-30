-- V407__rbac_concurrency_backpressure_rules.sql
-- Simple backpressure: pause canonicalization if backlog exceeds threshold
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM rbac.canon_queue WHERE status = 'pending') > 2000 THEN
    -- Introduce a cooldown to throttle further canonicalizations
    UPDATE rbac.canon_circuit_breaker SET next_attempt_time = NOW() + INTERVAL '5 minutes' WHERE id = 1;
  END IF;
END;
$$ LANGUAGE plpgsql;
