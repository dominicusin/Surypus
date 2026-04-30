-- ============================================================================
-- Chaos Engineering Support
-- ============================================================================

-- Chaos experiment definitions
CREATE TABLE IF NOT EXISTS chaos_experiments (
    id SERIAL PRIMARY KEY,
    experiment_name TEXT UNIQUE NOT NULL,
    experiment_type TEXT CHECK (experiment_type IN ('latency', 'error', 'timeout', 'kill')),
    target_percentage FLOAT DEFAULT 10.0,
    duration_seconds INT DEFAULT 60,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chaos injection
CREATE OR REPLACE FUNCTION inject_chaos(
    p_experiment_type TEXT,
    p_target_percentage FLOAT DEFAULT 10.0
) RETURNS VOID AS $$
DECLARE
    v_random FLOAT;
BEGIN
    v_random := random() * 100;
    
    IF v_random <= p_target_percentage THEN
        CASE p_experiment_type
            WHEN 'latency' THEN
                PERFORM pg_sleep(random() * 2);  -- 0-2 second delay
            WHEN 'error' THEN
                RAISE EXCEPTION 'Injected chaos error';
            WHEN 'timeout' THEN
                PERFORM pg_sleep(30);  -- 30 second delay
            ELSE
                NULL;
        END CASE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Experiment results
CREATE TABLE IF NOT EXISTS chaos_results (
    id BIGSERIAL PRIMARY KEY,
    experiment_id INT REFERENCES chaos_experiments(id),
    execution_time TIMESTAMPTZ DEFAULT NOW(),
    affected_requests INT,
    failed_requests INT,
    latency_injected_ms INT
);

-- Run chaos experiment
CREATE OR REPLACE FUNCTION run_chaos_experiment(
    p_experiment_name TEXT
) RETURNS VOID AS $$
DECLARE
    v_experiment chaos_experiments%ROWTYPE;
BEGIN
    SELECT * INTO v_experiment FROM chaos_experiments 
    WHERE experiment_name = p_experiment_name AND is_active = TRUE;
    
    IF v_experiment IS NULL THEN
        RETURN;
    END IF;
    
    PERFORM inject_chaos(v_experiment.experiment_type, v_experiment.target_percentage);
END;
$$ LANGUAGE plpgsql;