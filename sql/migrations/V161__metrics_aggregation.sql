-- ============================================================================
-- Metrics Aggregation
-- ============================================================================

-- Metrics aggregation table (time-series)
CREATE TABLE IF NOT EXISTS metrics_aggregation (
    id SERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_labels JSONB DEFAULT '{}',
    value NUMERIC NOT NULL,
    aggregation_type TEXT CHECK (aggregation_type IN ('sum', 'avg', 'min', 'max', 'count')),
    time_bucket TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(metric_name, metric_labels, time_bucket)
);

-- Index for time-series queries
CREATE INDEX IF NOT EXISTS idx_metrics_time ON metrics_aggregation(time_bucket DESC, metric_name);
CREATE INDEX IF NOT EXISTS idx_metrics_labels ON metrics_aggregation((metric_labels->>'tenant_id'), metric_name);

-- Record metric
CREATE OR REPLACE FUNCTION metrics_record(
    p_metric_name TEXT,
    p_value NUMERIC,
    p_labels JSONB DEFAULT '{}',
    p_aggregation_type TEXT DEFAULT 'sum'
) RETURNS VOID AS $$
DECLARE
    v_bucket TIMESTAMP WITH TIME ZONE;
BEGIN
    v_bucket := DATE_TRUNC('minute', NOW());
    
    INSERT INTO metrics_aggregation (metric_name, metric_labels, value, aggregation_type, time_bucket)
    VALUES (p_metric_name, p_labels, p_value, p_aggregation_type, v_bucket)
    ON CONFLICT (metric_name, metric_labels, time_bucket) DO UPDATE SET
        value = CASE 
            WHEN metrics_aggregation.aggregation_type = 'sum' THEN metrics_aggregation.value + EXCLUDED.value
            WHEN metrics_aggregation.aggregation_type = 'avg' THEN (metrics_aggregation.value + EXCLUDED.value) / 2
            WHEN metrics_aggregation.aggregation_type = 'max' THEN GREATEST(metrics_aggregation.value, EXCLUDED.value)
            WHEN metrics_aggregation.aggregation_type = 'min' THEN LEAST(metrics_aggregation.value, EXCLUDED.value)
            ELSE EXCLUDED.value
        END;
END;
$$ LANGUAGE plpgsql;

-- Query metrics
CREATE OR REPLACE FUNCTION metrics_query(
    p_metric_name TEXT,
    p_from TIMESTAMP WITH TIME ZONE,
    p_to TIMESTAMP WITH TIME ZONE,
    p_labels JSONB DEFAULT NULL
) RETURNS TABLE(time_bucket TIMESTAMP WITH TIME ZONE, value NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT m.time_bucket, SUM(m.value) as value
    FROM metrics_aggregation m
    WHERE m.metric_name = p_metric_name
      AND m.time_bucket BETWEEN p_from AND p_to
      AND (p_labels IS NULL OR m.metric_labels @> p_labels)
    GROUP BY m.time_bucket
    ORDER BY m.time_bucket;
END;
$$ LANGUAGE plpgsql;

-- Common metrics recording helper
CREATE OR REPLACE FUNCTION metrics_record_event(p_tenant_id UUID) RETURNS VOID AS $$
BEGIN
    PERFORM metrics_record('events_total', 1, jsonb_build_object('tenant_id', p_tenant_id), 'sum');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION metrics_record_projection(
    p_projection_name TEXT,
    p_duration_ms INT,
    p_status TEXT
) RETURNS VOID AS $$
BEGIN
    PERFORM metrics_record(
        'projection_duration_ms', 
        p_duration_ms, 
        jsonb_build_object('projection', p_projection_name, 'status', p_status),
        'avg'
    );
END;
$$ LANGUAGE plpgsql;