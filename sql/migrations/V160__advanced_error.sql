-- ============================================================================
-- Advanced Error Handling
-- ============================================================================

-- Error classification
CREATE TABLE IF NOT EXISTS error_classification (
    id SERIAL PRIMARY KEY,
    error_pattern TEXT UNIQUE NOT NULL,
    error_category TEXT CHECK (error_category IN (
        'validation', 'concurrency', 'permission', 
        'resource', 'integrity', 'timeout', 'unknown'
    )),
    severity INT CHECK (severity BETWEEN 1 AND 5),
    recommended_action TEXT
);

-- Default classifications
INSERT INTO error_classification (error_pattern, error_category, severity, recommended_action)
VALUES 
    ('%not null%', 'validation', 2, 'Check required fields'),
    ('%unique%', 'integrity', 2, 'Check for duplicate'),
    ('%foreign key%', 'integrity', 2, 'Check related record'),
    ('%permission%', 'permission', 3, 'Check user role'),
    ('%timeout%', 'timeout', 3, 'Increase timeout'),
    ('%deadlock%', 'concurrency', 4, 'Retry with backoff'),
    ('%cache%', 'resource', 3, 'Clear cache'),
    ('%connection%', 'resource', 4, 'Check pool')
ON CONFLICT (error_pattern) DO NOTHING;

-- Error handler registry
CREATE TABLE IF NOT EXISTS error_handlers (
    handler_id SERIAL PRIMARY KEY,
    error_category TEXT NOT NULL UNIQUE,
    retry_allowed BOOLEAN DEFAULT TRUE,
    max_retries INT DEFAULT 3,
    backoff_multiplier NUMERIC DEFAULT 2.0,
    handler_function TEXT
);

INSERT INTO error_handlers (error_category, retry_allowed, max_retries, backoff_multiplier)
VALUES 
    ('concurrency', TRUE, 3, 2.0),
    ('timeout', TRUE, 2, 1.5),
    ('resource', TRUE, 3, 2.0),
    ('validation', FALSE, 0, 1.0),
    ('integrity', FALSE, 0, 1.0),
    ('permission', FALSE, 0, 1.0)
ON CONFLICT (error_category) DO NOTHING;

-- Smart error classification
CREATE OR REPLACE FUNCTION classify_error(
    p_error_message TEXT
) RETURNS TABLE(category TEXT, severity INT, action TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.error_category::TEXT,
        ec.severity,
        ec.recommended_action::TEXT
    FROM error_classification ec
    WHERE p_error_message ILIKE ec.error_pattern
    ORDER BY ec.severity DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Error recovery attempt
CREATE OR REPLACE FUNCTION attempt_error_recovery(
    p_error_message TEXT,
    p_context JSONB DEFAULT '{}'
) RETURNS BOOLEAN AS $$
DECLARE
    v_category TEXT;
    v_handler RECORD;
    v_recovered BOOLEAN := FALSE;
BEGIN
    SELECT category INTO v_category 
    FROM classify_error(p_error_message) LIMIT 1;
    
    IF v_category IS NOT NULL THEN
        SELECT * INTO v_handler
        FROM error_handlers 
        WHERE error_category = v_category AND retry_allowed = TRUE;
        
        IF v_handler.handler_id IS NOT NULL THEN
            v_recovered := TRUE;
        END IF;
    END IF;
    
    RETURN v_recovered;
END;
$$ LANGUAGE plpgsql;