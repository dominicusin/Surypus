-- V385__rbac_concurrency_short_circuit.sql
-- Short-circuit canonicalization if queue backlog is high
DO $$
BEGIN
  IF (SELECT count(*) FROM rbac.canon_queue WHERE status = 'pending') > 1000 THEN
    -- set a quick cooldown flag; use existing circuit breaker to prevent thrash
    PERFORM rbac.update_canon_circuit_breaker(FALSE);
  END IF;
END;
$$ LANGUAGE plpgsql;
