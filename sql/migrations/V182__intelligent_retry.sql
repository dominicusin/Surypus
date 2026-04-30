-- ============================================================================
-- Intelligent Retry with Exponential Backoff
-- ============================================================================

-- Retry configuration
CREATE TABLE IF NOT EXISTS retry_config (
    id SERIAL PRIMARY KEY,
    operation_type TEXT UNIQUE NOT NULL,
    max_attempts INT DEFAULT 3,
    initial_delay_ms INT DEFAULT 100,
    max_delay_ms INT DEFAULT 30000,
    backoff_multiplier NUMERIC DEFAULT 2.0,
    jitter_enabled BOOLEAN DEFAULT TRUE
);

-- Default retry configs
INSERT INTO retry_config (operation_type, max_attempts, initial_delay_ms, backoff_multiplier)
VALUES 
    ('event_append', 5, 100, 2.0),
    ('projection', 3, 200, 2.0),
    ('outbox_publish', 10, 50, 1.5),
    ('dlq_retry', 15, 1000, 2.0)
ON CONFLICT (operation_type) DO NOTHING;

-- Calculate delay
CREATE OR REPLACE FUNCTION calculate_retry_delay(
    p_attempt INT,
    p_operation_type TEXT
) RETURNS INT AS $$
DECLARE
    v_config RECORD;
    v_delay INT;
BEGIN
    SELECT * INTO v_config FROM retry_config WHERE operation_type = p_operation_type;
    
    IF v_config IS NULL THEN
        RETURN 1000;  -- Default 1 second
    END IF;
    
    v_delay := v_config.initial_delay_ms * POWER(v_config.backoff_multiplier::NUMERIC, p_attempt);
    v_delay := LEAST(v_delay, v_config.max_delay_ms);
    
    IF v_config.jitter_enabled THEN
        v_delay := v_delay * (0.5 + random());
    END IF;
    
    RETURN v_delay::INT;
END;
$$ LANGUAGE plpgsql;

-- Retry wrapper
CREATE OR REPLACE FUNCTION with_retry(
    p_operation_type TEXT,
    p_sql TEXT
) RETURNS VOID AS $$
DECLARE
    v_config RECORD;
    v_attempt INT := 0;
    v_delay INT;
BEGIN
    SELECT * INTO v_config FROM retry_config WHERE operation_type = p_operation_type;
    
    LOOP
        BEGIN
            EXECUTE p_sql;
            RETURN;
        EXCEPTION WHEN OTHERS THEN
            v_attempt := v_attempt + 1;
            
            IF v_attempt >= COALESCE(v_config.max_attempts, 3) THEN
                RAISE;
            END IF;
            
            v_delay := calculate_retry_delay(v_attempt, p_operation_type);
            PERFORM pg_sleep(v_delay / 1000.0);
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;