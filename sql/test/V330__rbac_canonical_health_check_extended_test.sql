-- V330__rbac_canonical_health_check_extended_test.sql
-- Test extended health check functions
DO $$
DECLARE
    v_health_text TEXT;
    v_health_json JSONB;
    v_inconsistencies INTEGER;
BEGIN
    -- Test backward compatible text health check
    v_health_text := rbac.canon_health();
    -- Should be either 'OK' or start with 'INCONSISTENT:'
    IF v_health_text <> 'OK' AND v_health_text NOT LIKE 'INCONSISTENT:%' THEN
        RAISE EXCEPTION 'Unexpected canon_health output: %', v_health_text;
    END IF;
    
    -- Test detailed health check
    v_health_json := rbac.canon_health_detailed();
    -- Ensure it's valid JSON and has expected keys
    IF v_health_json IS NULL THEN
        RAISE EXCEPTION 'canon_health_detailed returned NULL';
    END IF;
    
    -- Check for required keys
    IF NOT (v_health_json ? 'consistent') THEN
        RAISE EXCEPTION 'Missing key "consistent" in health detailed';
    END IF;
    IF NOT (v_health_json ? 'inconsistency_count') THEN
        RAISE EXCEPTION 'Missing key "inconsistency_count" in health detailed';
    END IF;
    IF NOT (v_health_json ? 'timestamp') THEN
        RAISE EXCEPTION 'Missing key "timestamp" in health detailed';
    END IF;
    
    -- Ensure inconsistency_count matches the count function
    v_inconsistencies := rbac.count_canon_inconsistencies();
    IF (v_health_json ->> 'inconsistency_count')::INTEGER <> v_inconsistencies THEN
        RAISE EXCEPTION 'inconsistency_count mismatch: health_json=% vs count_function=%', 
            (v_health_json ->> 'inconsistency_count'), v_inconsistencies;
    END IF;
    
    -- Ensure consistent boolean is correct
    IF (v_health_json ->> 'consistent')::BOOLEAN <> (v_inconsistencies = 0) THEN
        RAISE EXCEPTION 'consistent flag mismatch';
    END IF;
    
    -- Optionally, check that status is either 'healthy' or 'unhealthy'
    IF v_health_json ->> 'status' NOT IN ('healthy', 'unhealthy') THEN
        RAISE EXCEPTION 'Unexpected status: %', (v_health_json ->> 'status');
    END IF;
END;
$$ LANGUAGE plpgsql;