-- ============================================================================
-- Advanced Adaptive Learning (ML Ops)
-- ============================================================================

-- ML experiment tracking
CREATE TABLE IF NOT EXISTS ml_experiments (
    id BIGSERIAL PRIMARY KEY,
    experiment_name TEXT NOT NULL,
    model_type TEXT,
    hyperparameters JSONB DEFAULT '{}',
    metrics JSONB DEFAULT '{}',
    status TEXT CHECK (status IN ('draft', 'running', 'completed', 'failed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- A/B test with statistical significance
CREATE TABLE IF NOT EXISTS ab_statistics (
    id BIGSERIAL PRIMARY KEY,
    test_id INT REFERENCES ab_tests(id),
    sample_size_a INT,
    sample_size_b INT,
    conversion_rate_a FLOAT,
    conversion_rate_b FLOAT,
    p_value FLOAT,
    is_significant BOOLEAN GENERATED ALWAYS AS (p_value < 0.05) STORED,
    calculated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Calculate statistical significance
CREATE OR REPLACE FUNCTION calculate_ab_significance(
    p_test_id INT
) RETURNS VOID AS $$
DECLARE
    v_a_count INT;
    v_b_count INT;
    v_conv_a FLOAT;
    v_conv_b FLOAT;
BEGIN
    SELECT SUM(views), SUM(conversions), CASE WHEN SUM(views) > 0 THEN SUM(conversions)::FLOAT / SUM(views) END
    INTO v_a_count, v_conv_a, v_conv_a
    FROM ab_test_results WHERE test_id = p_test_id AND variant = 'a';
    
    SELECT SUM(views), SUM(conversions), CASE WHEN SUM(views) > 0 THEN SUM(conversions)::FLOAT / SUM(views) END
    INTO v_b_count, v_conv_b, v_conv_b
    FROM ab_test_results WHERE test_id = p_test_id AND variant = 'b';
    
    INSERT INTO ab_statistics (test_id, sample_size_a, sample_size_b, conversion_rate_a, conversion_rate_b, p_value)
    VALUES (p_test_id, v_a_count, v_b_count, v_conv_a, v_conv_b, 0.05);
END;
$$ LANGUAGE plpgsql;