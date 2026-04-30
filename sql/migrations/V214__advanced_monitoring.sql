-- ============================================================================
-- Advanced Monitoring & Observability
-- ============================================================================

-- Distributed tracing
CREATE TABLE IF NOT EXISTS traces (
    trace_id UUID PRIMARY KEY,
    span_id UUID NOT NULL,
    parent_span_id UUID,
    operation_name TEXT NOT NULL,
    service_name TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_ms INT,
    tags JSONB DEFAULT '{}',
    logs JSONB DEFAULT '[]'
);

-- Metrics histogram
CREATE TABLE IF NOT EXISTS metrics_histogram (
    id BIGSERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    tags JSONB DEFAULT '{}',
    bucket_bounds FLOAT[] DEFAULT '{0,5,10,25,50,100,250,500,1000,2500,5000,10000}',
    bucket_counts BIGINT[] DEFAULT ARRAY[0,0,0,0,0,0,0,0,0,0,0,0],
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Record histogram metric
CREATE OR REPLACE FUNCTION record_histogram(
    p_metric_name TEXT,
    p_value FLOAT,
    p_tags JSONB DEFAULT '{}'
) RETURNS VOID AS $$
DECLARE
    v_bucket_counts BIGINT[];
    v_bucket_bound FLOAT;
BEGIN
    v_bucket_counts := ARRAY[0,0,0,0,0,0,0,0,0,0,0,0];
    
    FOR v_bucket_bound IN SELECT unnest(ARRAY[0,5,10,25,50,100,250,500,1000,2500,5000,10000])
    LOOP
        IF p_value <= v_bucket_bound THEN
            v_bucket_counts[array_position(ARRAY[0,5,10,25,50,100,250,500,1000,2500,5000,10000], v_bucket_bound)] := 
                v_bucket_counts[array_position(ARRAY[0,5,10,25,50,100,250,500,1000,2500,5000,10000], v_bucket_bound)] + 1;
        END IF;
    END LOOP;
    
    INSERT INTO metrics_histogram (metric_name, tags, bucket_counts, recorded_at)
    VALUES (p_metric_name, p_tags, v_bucket_counts, NOW())
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Service health endpoint
CREATE OR REPLACE FUNCTION service_health_check() RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    v_result := jsonb_build_object(
        'status', 'healthy',
        'timestamp', NOW(),
        'database', jsonb_build_object(
            'connections', (SELECT COUNT(*) FROM pg_stat_activity),
            'transactions', (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active')
        ),
        'event_store', jsonb_build_object(
            'total_events', (SELECT COUNT(*) FROM event_store),
            'pending_outbox', (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE)
        ),
        'projections', jsonb_build_object(
            'total', (SELECT COUNT(*) FROM projections),
            'failures_1h', (SELECT COUNT(*) FROM projection_audit WHERE status = 'failure' AND created_at > NOW() - INTERVAL '1 hour')
        )
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;