-- ============================================================================
-- Advanced Analytics & ML Ops
-- ============================================================================

-- ML model training runs
CREATE TABLE IF NOT EXISTS ml_training_runs (
    id BIGSERIAL PRIMARY KEY,
    model_id INT REFERENCES ml_models(id),
    training_data_start TIMESTAMPTZ,
    training_data_end TIMESTAMPTZ,
    model_metrics JSONB,
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- A/B test definitions
CREATE TABLE IF NOT EXISTS ab_tests (
    id SERIAL PRIMARY KEY,
    test_name TEXT UNIQUE NOT NULL,
    variant_a JSONB NOT NULL,
    variant_b JSONB NOT NULL,
    traffic_split NUMERIC CHECK (traffic_split BETWEEN 0 AND 100),
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    status TEXT CHECK (status IN ('draft', 'running', 'paused', 'completed'))
);

-- A/B test results
CREATE TABLE IF NOT EXISTS ab_test_results (
    test_id INT REFERENCES ab_tests(id),
    variant TEXT CHECK (variant IN ('a', 'b')),
    conversions INT DEFAULT 0,
    views INT DEFAULT 0,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Track feature usage
CREATE TABLE IF NOT EXISTS feature_usage (
    id BIGSERIAL PRIMARY KEY,
    feature_name TEXT NOT NULL,
    tenant_id UUID,
    user_id UUID,
    usage_count INT DEFAULT 1,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feature usage analytics
CREATE OR REPLACE FUNCTION track_feature_usage(
    p_feature_name TEXT,
    p_tenant_id UUID,
    p_user_id UUID
) RETURNS VOID AS $$
BEGIN
    INSERT INTO feature_usage (feature_name, tenant_id, user_id)
    VALUES (p_feature_name, p_tenant_id, p_user_id)
    ON CONFLICT DO UPDATE SET
        usage_count = feature_usage.usage_count + 1,
        recorded_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Get top features
CREATE OR REPLACE FUNCTION get_top_features(p_limit INT DEFAULT 10)
RETURNS TABLE(feature_name TEXT, usage_count BIGINT, unique_users BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT fu.feature_name, SUM(fu.usage_count), COUNT(DISTINCT fu.user_id)
    FROM feature_usage fu
    GROUP BY fu.feature_name
    ORDER BY SUM(fu.usage_count) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;