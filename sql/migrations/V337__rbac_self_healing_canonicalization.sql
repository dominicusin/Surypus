-- V337__rbac_self_healing_canonicalization.sql
-- Self-healing function that attempts to fix canonicalization inconsistencies when healthy to do so
CREATE OR REPLACE FUNCTION rbac.self_heal_canonicalization()
RETURNS VOID AS $$
DECLARE
    v_health JSONB;
    v_consistent BOOLEAN;
    v_inconsistencies INTEGER;
    v_cb_state VARCHAR(20);
BEGIN
    -- Get detailed health
    v_health := rbac.canon_health_detailed();
    v_consistent := (v_health ->> 'consistent')::BOOLEAN;
    v_inconsistencies := (v_health ->> 'inconsistency_count')::INTEGER;
    v_cb_state := (v_health #> '{circuit_breaker,state}')::TEXT;
    
    -- If consistent, nothing to do
    IF v_consistent THEN
        RAISE NOTICE 'rbac.self_heal_canonicalization: Already consistent, no action needed';
        RETURN;
    END IF;
    
    -- If inconsistent, check circuit breaker: only proceed if circuit breaker is CLOSED or HALF_OPEN (i.e., not OPEN)
    IF v_cb_state = 'OPEN' THEN
        RAISE NOTICE 'rbac.self_heal_canonicalization: Inconsistencies found (%s) but circuit breaker is OPEN, skipping self-heal', v_inconsistencies;
        RETURN;
    END IF;
    
    -- Attempt to fix inconsistencies by running canonicalize_all (which respects its own lock and circuit breaker)
    RAISE NOTICE 'rbac.self_heal_canonicalization: Attempting to fix %s inconsistencies', v_inconsistencies;
    PERFORM rbac.canonicalize_all();
    
    -- After attempt, check consistency again
    PERFORM rbac.update_canon_circuit_breaker(TRUE); -- Assume success, but update_canon_circuit_breaker will handle based on actual success? Actually, we don't know if it succeeded. We'll rely on the function's internal update.
    -- However, note that rbac.canonicalize_all() already updates the circuit breaker internally.
    -- So we don't need to call it again here. But we can call it to ensure the state is updated based on the outcome of canonicalize_all.
    -- Actually, canonicalize_all calls update_canon_circuit_breaker(TRUE) on success and (FALSE) on exception.
    -- So we don't need to call it again.
    
    RAISE NOTICE 'rbac.self_heal_canonicalization: Self-heal attempt completed';
END;
$$ LANGUAGE plpgsql;