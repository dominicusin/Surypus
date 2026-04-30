-- V404__rbac_can_run_canon.sql
-- Decide whether canonicalization can run based on circuit breaker and backlog
CREATE OR REPLACE FUNCTION rbac.can_run_canon() RETURNS BOOLEAN AS $$
DECLARE
  cb_state VARCHAR(20);
  backlog INT;
BEGIN
  SELECT state INTO cb_state FROM rbac.canon_circuit_breaker WHERE id = 1;
  IF cb_state = 'OPEN' THEN
    RETURN FALSE;
  END IF;
  SELECT COUNT(*) INTO backlog FROM rbac.canon_queue WHERE status = 'pending';
  IF backlog > 1000 THEN
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
