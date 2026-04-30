-- V355__rbac_self_heal_policy.sql
-- Self-heal policy: perform restoration only under safe, canonical conditions
CREATE OR REPLACE FUNCTION rbac.self_heal_policy() RETURNS VOID AS $$
DECLARE
  v_incons INTEGER;
  v_consistent BOOLEAN;
BEGIN
  v_incons := rbac.count_canon_inconsistencies();
  v_consistent := (v_incons = 0);
  -- Only attempt self-heal if there are inconsistencies and canonicalization is safe
  IF v_incons > 0 AND rbac.check_canon_circuit_breaker() THEN
    -- Trigger full canonicalization; internal logic handles locking
    PERFORM rbac.canonicalize_all();
  ELSE
    RAISE NOTICE 'rbac.self_heal_policy: no action taken (inconsistencies=%, canary=%)', v_incons, rbac.canon_health();
  END IF;
END;
$$ LANGUAGE plpgsql;
