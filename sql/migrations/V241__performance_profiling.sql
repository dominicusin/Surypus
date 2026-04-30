-- ============================================================================
-- Advanced Database Performance Profiling
-- ============================================================================

-- Query profiling
CREATE TABLE IF NOT EXISTS query_profiles (
    id BIGSERIAL PRIMARY KEY,
    query_hash TEXT NOT NULL,
    query_template TEXT NOT NULL,
    min_time_ms INT,
    max_time_ms INT,
    avg_time_ms NUMERIC,
    stddev_time_ms NUMERIC,
    execution_count BIGINT DEFAULT 1,
    first_seen TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    statistics JSONB DEFAULT '{}'
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_query_profiles_hash ON query_profiles(query_hash);

-- Auto-profiling function
CREATE OR REPLACE FUNCTION profile_query(
    p_query TEXT,
    p_execution_time_ms INT
) RETURNS VOID AS $$
DECLARE
    v_hash TEXT;
    v_template TEXT;
BEGIN
    v_hash := md5(p_query)::TEXT;
    v_template := p_query;
    
    INSERT INTO query_profiles (query_hash, query_template, min_time_ms, max_time_ms, avg_time_ms, execution_count, first_seen, last_seen)
    VALUES (v_hash, v_template, p_execution_time_ms, p_execution_time_ms, p_execution_time_ms, 1, NOW(), NOW())
    ON CONFLICT (query_hash) DO UPDATE SET
        execution_count = query_profiles.execution_count + 1,
        min_time_ms = LEAST(query_profiles.min_time_ms, p_execution_time_ms),
        max_time_ms = GREATEST(query_profiles.max_time_ms, p_execution_time_ms),
        avg_time_ms = (query_profiles.avg_time_ms * query_profiles.execution_count + p_execution_time_ms) / (query_profiles.execution_count + 1),
        last_seen = NOW();
END;
$$ LANGUAGE plpgsql;

-- Get slow queries
CREATE OR REPLACE FUNCTION get_slow_queries(p_min_avg_ms INT DEFAULT 1000)
RETURNS TABLE(query_template TEXT, avg_time_ms NUMERIC, execution_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT qp.query_template, qp.avg_time_ms, qp.execution_count
    FROM query_profiles qp
    WHERE qp.avg_time_ms > p_min_avg_ms
    ORDER BY qp.avg_time_ms DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;