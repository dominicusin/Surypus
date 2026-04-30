-- Retry policy for failed projections
CREATE TABLE IF NOT EXISTS projection_retry_policy (
    policy_id BIGSERIAL PRIMARY KEY,
    projection_name TEXT NOT NULL,
    max_retries INT DEFAULT 3,
    retry_interval INTERVAL DEFAULT '1 minute',
    backoff_multiplier NUMERIC DEFAULT 2.0,
    UNIQUE(projection_name)
);

-- Default retry policies
INSERT INTO projection_retry_policy (projection_name, max_retries, retry_interval, backoff_multiplier)
VALUES 
    ('TestProj', 5, '30 seconds', 1.5),
    ('FailingProj', 2, '1 minute', 2.0)
ON CONFLICT (projection_name) DO NOTHING;

-- Function to check and apply retry
CREATE OR REPLACE FUNCTION projection_should_retry(
    p_projection_name TEXT,
    p_attempt_count INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_max_retries INT;
BEGIN
    SELECT max_retries INTO v_max_retries
    FROM projection_retry_policy
    WHERE projection_name = p_projection_name;
    
    RETURN COALESCE(v_max_retries, 3) > p_attempt_count;
END;
$$ LANGUAGE plpgsql;