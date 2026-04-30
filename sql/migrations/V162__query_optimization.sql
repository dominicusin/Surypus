-- ============================================================================
-- Query Optimization Hints
-- ============================================================================

-- Query hints table
CREATE TABLE IF NOT EXISTS query_hints (
    hint_id SERIAL PRIMARY KEY,
    query_pattern TEXT UNIQUE NOT NULL,
    hint_text TEXT NOT NULL,
    estimated_improvement TEXT,
    is_enabled BOOLEAN DEFAULT TRUE
);

-- Default optimization hints
INSERT INTO query_hints (query_pattern, hint_text, estimated_improvement)
VALUES 
    ('%event_store%aggregate_id%', 'Ensure index on (aggregate_id, sequence_number)', 'O(n) → O(log n)'),
    ('%event_store%tenant_id%', 'Use partition pruning', 'Full scan → Partition scan'),
    ('%projection_audit%event_type%', 'Add composite index on (event_type, created_at)', 'O(n) → O(log n)'),
    ('%aggregates%tenant_id%', 'Use covering index', 'Index + Table → Index only')
ON CONFLICT (query_pattern) DO NOTHING;

-- Query plan analyzer
CREATE OR REPLACE FUNCTION analyze_query_plan(
    p_sql TEXT
) RETURNS TABLE(
    plan_text TEXT,
    startup_cost NUMERIC,
    total_cost NUMERIC,
    plan_rows BIGINT,
    plan_width BIGINT
) AS $$
BEGIN
    RETURN QUERY
    EXPLAIN (FORMAT TEXT) SELECT p_sql;
END;
$$ LANGUAGE plpgsql;

-- Slow query log
CREATE TABLE IF NOT EXISTS slow_query_log (
    id SERIAL PRIMARY KEY,
    query_text TEXT NOT NULL,
    call_count INT DEFAULT 1,
    total_time NUMERIC DEFAULT 0,
    avg_time NUMERIC DEFAULT 0,
    min_time NUMERIC,
    max_time NUMERIC,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Log slow query
CREATE OR REPLACE FUNCTION log_slow_query(
    p_query TEXT,
    p_execution_time NUMERIC
) RETURNS VOID AS $$
BEGIN
    IF p_execution_time > 1000 THEN  -- Threshold: 1 second
        INSERT INTO slow_query_log (query_text, call_count, total_time, avg_time, min_time, max_time, last_seen)
        VALUES (p_query, 1, p_execution_time, p_execution_time, p_execution_time, p_execution_time, NOW())
        ON CONFLICT (query_text) DO UPDATE SET
            call_count = slow_query_log.call_count + 1,
            total_time = slow_query_log.total_time + p_execution_time,
            avg_time = (slow_query_log.total_time + p_execution_time) / (slow_query_log.call_count + 1),
            max_time = GREATEST(slow_query_log.max_time, p_execution_time),
            min_time = LEAST(slow_query_log.min_time, p_execution_time),
            last_seen = NOW();
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Get slow queries
CREATE OR REPLACE FUNCTION get_slow_queries(p_limit INT DEFAULT 10)
RETURNS TABLE(query_text TEXT, call_count INT, avg_time NUMERIC, total_time NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT sq.query_text, sq.call_count, sq.avg_time, sq.total_time
    FROM slow_query_log sq
    ORDER BY sq.total_time DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;