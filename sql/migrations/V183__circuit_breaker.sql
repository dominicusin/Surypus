-- ============================================================================
-- Circuit Breaker Pattern
-- ============================================================================

-- Circuit breaker state
CREATE TABLE IF NOT EXISTS circuit_breakers (
    id SERIAL PRIMARY KEY,
    circuit_name TEXT UNIQUE NOT NULL,
    state TEXT CHECK (state IN ('closed', 'open', 'half_open')) DEFAULT 'closed',
    failure_count INT DEFAULT 0,
    success_count INT DEFAULT 0,
    last_failure TIMESTAMP WITH TIME ZONE,
    opened_at TIMESTAMP WITH TIME ZONE,
    threshold_failures INT DEFAULT 5,
    timeout_seconds INT DEFAULT 60,
    half_open_attempts INT DEFAULT 3
);

-- Initialize circuit
CREATE OR REPLACE FUNCTION circuit_init(
    p_circuit_name TEXT,
    p_threshold_failures INT DEFAULT 5,
    p_timeout_seconds INT DEFAULT 60
) RETURNS VOID AS $$
BEGIN
    INSERT INTO circuit_breakers (circuit_name, threshold_failures, timeout_seconds)
    VALUES (p_circuit_name, p_threshold_failures, p_timeout_seconds)
    ON CONFLICT (circuit_name) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Record success
CREATE OR REPLACE FUNCTION circuit_success(p_circuit_name TEXT) RETURNS VOID AS $$
DECLARE
    v_cb RECORD;
BEGIN
    SELECT * INTO v_cb FROM circuit_breakers WHERE circuit_name = p_circuit_name;
    
    IF v_cb.state = 'half_open' THEN
        v_cb.success_count := v_cb.success_count + 1;
        IF v_cb.success_count >= v_cb.half_open_attempts THEN
            UPDATE circuit_breakers SET state = 'closed', failure_count = 0, success_count = 0
            WHERE circuit_name = p_circuit_name;
        ELSE
            UPDATE circuit_breakers SET success_count = v_cb.success_count WHERE circuit_name = p_circuit_name;
        END IF;
    ELSIF v_cb.state = 'closed' THEN
        UPDATE circuit_breakers SET failure_count = 0 WHERE circuit_name = p_circuit_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Record failure
CREATE OR REPLACE FUNCTION circuit_failure(p_circuit_name TEXT) RETURNS VOID AS $$
DECLARE
    v_cb RECORD;
BEGIN
    SELECT * INTO v_cb FROM circuit_breakers WHERE circuit_name = p_circuit_name;
    
    v_cb.failure_count := v_cb.failure_count + 1;
    
    IF v_cb.state = 'closed' AND v_cb.failure_count >= v_cb.threshold_failures THEN
        UPDATE circuit_breakers SET state = 'open', opened_at = NOW(), failure_count = 0
        WHERE circuit_name = p_circuit_name;
    ELSIF v_cb.state = 'open' THEN
        IF v_cb.opened_at < NOW() - (v_cb.timeout_seconds || ' seconds')::INTERVAL THEN
            UPDATE circuit_breakers SET state = 'half_open', success_count = 0
            WHERE circuit_name = p_circuit_name;
        END IF;
    END IF;
    
    UPDATE circuit_breakers SET last_failure = NOW(), failure_count = v_cb.failure_count
    WHERE circuit_name = p_circuit_name AND state != 'half_open';
END;
$$ LANGUAGE plpgsql;

-- Check circuit
CREATE OR REPLACE FUNCTION circuit_can_execute(p_circuit_name TEXT) RETURNS BOOLEAN AS $$
DECLARE
    v_state TEXT;
BEGIN
    SELECT state INTO v_state FROM circuit_breakers WHERE circuit_name = p_circuit_name;
    RETURN COALESCE(v_state, 'closed') != 'open';
END;
$$ LANGUAGE plpgsql;