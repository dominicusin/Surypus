-- V415__rbac_self_heal_adaptive.sql
-- Adaptive self-heal policy:
CREATE OR REPLACE FUNCTION rbac.self_heal_adaptive() RETURNS VOID AS $$
BEGIN
  IF NOT rbac.is_canonical_consistent() AND rbac.check_canon_circuit_breaker() THEN
    PERFORM rbac.canonicalize_all();
  ELSE
    RAISE NOTICE 'rbac.self_heal_adaptive: nothing to heal or circuit breaker OPEN';
  END IF;
END;
$$ LANGUAGE plpgsql;
