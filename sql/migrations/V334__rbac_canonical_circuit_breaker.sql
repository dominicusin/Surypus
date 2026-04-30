-- V334__rbac_canonical_circuit_breaker.sql
-- Circuit breaker pattern for canonicalization to prevent cascading failures
CREATE TABLE IF NOT EXISTS rbac.canon_circuit_breaker (
    id SMALLINT PRIMARY KEY DEFAULT 1,
    failure_count INTEGER NOT NULL DEFAULT 0,
    last_failure_time TIMESTAMPTZ,
    state VARCHAR(20) NOT NULL DEFAULT 'CLOSED', -- CLOSED, OPEN, HALF_OPEN
    next_attempt_time TIMESTAMPTZ,
    failure_threshold INTEGER NOT NULL DEFAULT 5,
    timeout_seconds INTEGER NOT NULL DEFAULT 60,
    half_open_max_calls INTEGER NOT NULL DEFAULT 3,
    half_open_calls INTEGER NOT NULL DEFAULT 0
);

-- Initialize circuit breaker if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rbac.canon_circuit_breaker) THEN
        INSERT INTO rbac.canon_circuit_breaker (id) VALUES (1);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION rbac.update_canon_circuit_breaker(success BOOLEAN)
RETURNS VOID AS $$
DECLARE
    v_state VARCHAR(20);
    v_failure_count INTEGER;
    v_next_attempt TIMESTAMPTZ;
    v_half_open_calls INTEGER;
BEGIN
    -- Get current state
    SELECT state, failure_count, half_open_calls INTO v_state, v_failure_count, v_half_open_calls
    FROM rbac.canon_circuit_breaker WHERE id = 1;
    
    IF success THEN
        -- Success case: reset failure count, potentially close circuit breaker
        IF v_state = 'HALF_OPEN' THEN
            -- Successful call in half-open state: close the circuit breaker
            UPDATE rbac.canon_circuit_breaker
            SET state = 'CLOSED',
                failure_count = 0,
                half_open_calls = 0,
                next_attempt_time = NULL
            WHERE id = 1;
        ELSIF v_state = 'CLOSED' THEN
            -- Successful call in closed state: ensure failure count is zero
            UPDATE rbac.canon_circuit_breaker
            SET failure_count = 0,
                half_open_calls = 0
            WHERE id = 1;
        END IF;
    ELSE
        -- Failure case: increment failure count and potentially open circuit breaker
        IF v_state = 'CLOSED' THEN
            -- In failure count
            v_failure_count := v_failure_count + 1;
            
            IF v_failure_count >= (SELECT failure_threshold FROM rbac.canon_circuit_breaker WHERE id = 1) THEN
                -- Open the circuit breaker
                UPDATE rbac.canon_circuit_breaker
                SET state = 'OPEN',
                    failure_count = v_failure_count,
                    last_failure_time = NOW(),
                    next_attempt_time = NOW() + (SELECT timeout_seconds FROM rbac.canon_circuit_breaker WHERE id = 1) * INTERVAL '1 second',
                    half_open_calls = 0
                WHERE id = 1;
            ELSE
                -- Just update failure count
                UPDATE rbac.canon_circuit_breaker
                SET failure_count = v_failure_count
                WHERE id = 1;
            END IF;
        ELSIF v_state = 'HALF_OPEN' THEN
            -- Failure in half-open state: go back to open
            UPDATE rbac.canon_circuit_breaker
            SET state = 'OPEN',
                last_failure_time = NOW(),
                next_attempt_time = NOW() + (SELECT timeout_seconds FROM rbac.canon_circuit_breaker WHERE id = 1) * INTERVAL '1 second',
                half_open_calls = 0
            WHERE id = 1;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac.check_canon_circuit_breaker()
RETURNS BOOLEAN AS $$
DECLARE
    v_state VARCHAR(20);
    v_next_attempt TIMESTAMPTZ;
    v_half_open_calls INTEGER;
    v_half_open_max_calls INTEGER;
BEGIN
    -- Get current state
    SELECT state, next_attempt_time, half_open_calls INTO v_state, v_next_attempt, v_half_open_calls
    FROM rbac.canon_circuit_breaker WHERE id = 1;
    
    IF v_state = 'CLOSED' THEN
        RETURN TRUE; -- Allow execution
    ELSIF v_state = 'OPEN' THEN
        -- Check if timeout period has elapsed
        IF v_next_attempt IS NOT NULL AND NOW() >= v_next_attempt THEN
            -- Try half-open state
            UPDATE rbac.canon_circuit_breaker
            SET state = 'HALF_OPEN',
                half_open_calls = 0
            WHERE id = 1;
            RETURN TRUE; -- Allow trial execution
        ELSE
            RETURN FALSE; -- Still in open state, reject execution
        END IF;
    ELSIF v_state = 'HALF_OPEN' THEN
        -- Check if we've exceeded max calls in half-open state
        SELECT half_open_max_calls INTO v_half_open_max_calls FROM rbac.canon_circuit_breaker WHERE id = 1;
        IF v_half_open_calls < v_half_open_max_calls THEN
            -- Increment half-open calls and allow execution
            UPDATE rbac.canon_circuit_breaker
            SET half_open_calls = half_open_calls + 1
            WHERE id = 1;
            RETURN TRUE;
        ELSE
            RETURN FALSE; -- Too many calls in half-open state
        END IF;
    END IF;
    
    RETURN FALSE; -- Default to false
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac.get_canon_circuit_breaker_status()
RETURNS TABLE (
    state VARCHAR(20),
    failure_count INTEGER,
    last_failure_time TIMESTAMPTZ,
    next_attempt_time TIMESTAMPTZ,
    half_open_calls INTEGER,
    half_open_max_calls INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT state, failure_count, last_failure_time, next_attempt_time, half_open_calls,
           (SELECT half_open_max_calls FROM rbac.canon_circuit_breaker WHERE id = 1)
    FROM rbac.canon_circuit_breaker WHERE id = 1;
END;
$$ LANGUAGE plpgsql;