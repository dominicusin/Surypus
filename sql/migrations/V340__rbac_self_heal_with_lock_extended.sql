-- V340__rbac_self_heal_with_lock_extended.sql
-- Extend self-heal to use the safe wrapper when circuit is not OPEN
CREATE OR REPLACE FUNCTION rbac.self_heal_with_lock()
RETURNS VOID AS $$
BEGIN
  IF rbac.check_canon_circuit_breaker() THEN
    PERFORM rbac.self_heal_canonicalization();
  ELSE
    RAISE NOTICE 'rbac.self_heal_with_lock: circuit breaker OPEN, skipping self-heal';
  END IF;
END;
$$ LANGUAGE plpgsql;
