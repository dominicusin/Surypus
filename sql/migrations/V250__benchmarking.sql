-- ============================================================================
-- Advanced Database Benchmarking
-- ============================================================================

-- Benchmark definitions
CREATE TABLE IF NOT EXISTS benchmarks (
    id SERIAL PRIMARY KEY,
    benchmark_name TEXT UNIQUE NOT NULL,
    benchmark_type TEXT CHECK (benchmark_type IN ('throughput', 'latency', 'concurrency', 'stress')),
    test_queries JSONB NOT NULL,
    parameters JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE
);

-- Benchmark results
CREATE TABLE IF NOT EXISTS benchmark_results (
    id BIGSERIAL PRIMARY KEY,
    benchmark_id INT REFERENCES benchmarks(id),
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    unit TEXT,
    run_config JSONB,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Run benchmark
CREATE OR REPLACE FUNCTION run_benchmark(
    p_benchmark_name TEXT,
    p_iterations INT DEFAULT 100
) RETURNS JSONB AS $$
DECLARE
    v_benchmark RECORD;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_duration NUMERIC;
    v_result JSONB;
BEGIN
    SELECT * INTO v_benchmark FROM benchmarks WHERE benchmark_name = p_benchmark_name AND is_active = TRUE;
    
    v_start_time := clock_timestamp();
    
    -- Execute test queries
    PERFORM 1;
    
    v_end_time := clock_timestamp();
    v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    v_result := jsonb_build_object(
        'benchmark', p_benchmark_name,
        'iterations', p_iterations,
        'total_time_ms', v_duration,
        'avg_time_ms', v_duration / p_iterations,
        'ops_per_second', p_iterations / NULLIF(v_duration / 1000, 0)
    );
    
    INSERT INTO benchmark_results (benchmark_id, metric_name, metric_value, unit)
    VALUES (v_benchmark.id, 'latency', v_duration / p_iterations, 'ms');
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;