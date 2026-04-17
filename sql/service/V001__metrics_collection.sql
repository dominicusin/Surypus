-- ============================================================================
-- Metrics Collection Service
-- ============================================================================
-- Collects and aggregates metrics from event store and projections
-- ============================================================================

-- ============================================================================
-- METRICS TABLES
-- ============================================================================

-- Event processing metrics
CREATE TABLE IF NOT EXISTS metrics_event_processing (
    metric_id           BIGSERIAL PRIMARY KEY,
    tenant_id           UUID,
    aggregate_type      VARCHAR(64),
    event_type          VARCHAR(128),
    processing_time_ms  INT NOT NULL,
    success             BOOLEAN NOT NULL,
    error_type          VARCHAR(128),
    processed_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Projection lag metrics
CREATE TABLE IF NOT EXISTS metrics_projection_lag (
    metric_id           BIGSERIAL PRIMARY KEY,
    projection_name     VARCHAR(128) NOT NULL,
    last_sequence       BIGINT NOT NULL,
    current_sequence    BIGINT NOT NULL,
    lag_events          BIGINT GENERATED ALWAYS AS (current_sequence - last_sequence) STORED,
    lag_seconds         INT,
    measured_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Saga execution metrics
CREATE TABLE IF NOT EXISTS metrics_saga_execution (
    metric_id           BIGSERIAL PRIMARY KEY,
    saga_type           VARCHAR(128) NOT NULL,
    status              VARCHAR(32) NOT NULL,
    total_steps         INT NOT NULL,
    completed_steps     INT NOT NULL,
    execution_time_ms   INT,
    compensation_needed BOOLEAN DEFAULT FALSE,
    started_at          TIMESTAMP WITH TIME ZONE,
    completed_at        TIMESTAMP WITH TIME ZONE
);

-- Command execution metrics
CREATE TABLE IF NOT EXISTS metrics_command_execution (
    metric_id           BIGSERIAL PRIMARY KEY,
    command_type        VARCHAR(128) NOT NULL,
    aggregate_type      VARCHAR(64),
    execution_time_ms   INT NOT NULL,
    success             BOOLEAN NOT NULL,
    validation_time_ms  INT,
    persistence_time_ms INT,
    tenant_id           UUID,
    executed_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- API request metrics
CREATE TABLE IF NOT EXISTS metrics_api_requests (
    metric_id           BIGSERIAL PRIMARY KEY,
    endpoint            TEXT NOT NULL,
    method              VARCHAR(16) NOT NULL,
    status_code         INT,
    response_time_ms    INT NOT NULL,
    user_id             UUID,
    tenant_id           UUID,
    request_size_bytes  INT,
    response_size_bytes INT,
    error_message       TEXT,
    requested_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDICES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_metrics_event_processing_time 
    ON metrics_event_processing(processed_at, tenant_id);
CREATE INDEX IF NOT EXISTS idx_metrics_projection_lag_name 
    ON metrics_projection_lag(projection_name, measured_at);
CREATE INDEX IF NOT EXISTS idx_metrics_saga_execution_time 
    ON metrics_saga_execution(completed_at, saga_type);
CREATE INDEX IF NOT EXISTS idx_metrics_command_execution_time 
    ON metrics_command_execution(executed_at, command_type);
CREATE INDEX IF NOT EXISTS idx_metrics_api_requests_time 
    ON metrics_api_requests(requested_at, endpoint);

-- ============================================================================
-- METRICS COLLECTION FUNCTIONS
-- ============================================================================

-- Record event processing metric
CREATE OR REPLACE FUNCTION metrics_record_event_processing(
    p_tenant_id UUID,
    p_aggregate_type VARCHAR(64),
    p_event_type VARCHAR(128),
    p_processing_time_ms INT,
    p_success BOOLEAN,
    p_error_type VARCHAR(128) DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_metric_id BIGINT;
BEGIN
    INSERT INTO metrics_event_processing (
        tenant_id, aggregate_type, event_type, processing_time_ms, success, error_type
    ) VALUES (
        p_tenant_id, p_aggregate_type, p_event_type, p_processing_time_ms, p_success, p_error_type
    )
    RETURNING metric_id INTO v_metric_id;
    
    RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql;

-- Record projection lag
CREATE OR REPLACE FUNCTION metrics_record_projection_lag(
    p_projection_name VARCHAR(128),
    p_last_sequence BIGINT,
    p_current_sequence BIGINT,
    p_lag_seconds INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_metric_id BIGINT;
BEGIN
    INSERT INTO metrics_projection_lag (
        projection_name, last_sequence, current_sequence, lag_seconds
    ) VALUES (
        p_projection_name, p_last_sequence, p_current_sequence, p_lag_seconds
    )
    RETURNING metric_id INTO v_metric_id;
    
    RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql;

-- Record saga execution
CREATE OR REPLACE FUNCTION metrics_record_saga_execution(
    p_saga_type VARCHAR(128),
    p_status VARCHAR(32),
    p_total_steps INT,
    p_completed_steps INT,
    p_execution_time_ms INT,
    p_compensation_needed BOOLEAN DEFAULT FALSE,
    p_started_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_completed_at TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_metric_id BIGINT;
BEGIN
    INSERT INTO metrics_saga_execution (
        saga_type, status, total_steps, completed_steps, execution_time_ms,
        compensation_needed, started_at, completed_at
    ) VALUES (
        p_saga_type, p_status, p_total_steps, p_completed_steps, p_execution_time_ms,
        p_compensation_needed, p_started_at, p_completed_at
    )
    RETURNING metric_id INTO v_metric_id;
    
    RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql;

-- Record command execution
CREATE OR REPLACE FUNCTION metrics_record_command(
    p_command_type VARCHAR(128),
    p_aggregate_type VARCHAR(64),
    p_execution_time_ms INT,
    p_success BOOLEAN,
    p_validation_time_ms INT DEFAULT NULL,
    p_persistence_time_ms INT DEFAULT NULL,
    p_tenant_id UUID DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_metric_id BIGINT;
BEGIN
    INSERT INTO metrics_command_execution (
        command_type, aggregate_type, execution_time_ms, success,
        validation_time_ms, persistence_time_ms, tenant_id
    ) VALUES (
        p_command_type, p_aggregate_type, p_execution_time_ms, p_success,
        p_validation_time_ms, p_persistence_time_ms, p_tenant_id
    )
    RETURNING metric_id INTO v_metric_id;
    
    RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql;

-- Record API request
CREATE OR REPLACE FUNCTION metrics_record_api_request(
    p_endpoint TEXT,
    p_method VARCHAR(16),
    p_status_code INT,
    p_response_time_ms INT,
    p_user_id UUID DEFAULT NULL,
    p_tenant_id UUID DEFAULT NULL,
    p_request_size_bytes INT DEFAULT NULL,
    p_response_size_bytes INT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_metric_id BIGINT;
BEGIN
    INSERT INTO metrics_api_requests (
        endpoint, method, status_code, response_time_ms, user_id, tenant_id,
        request_size_bytes, response_size_bytes, error_message
    ) VALUES (
        p_endpoint, p_method, p_status_code, p_response_time_ms, p_user_id, p_tenant_id,
        p_request_size_bytes, p_response_size_bytes, p_error_message
    )
    RETURNING metric_id INTO v_metric_id;
    
    RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AGGREGATION VIEWS
-- ============================================================================

-- Event processing stats (last hour)
CREATE OR REPLACE VIEW metrics_event_stats_hourly AS
SELECT 
    tenant_id,
    aggregate_type,
    event_type,
    DATE_TRUNC('hour', processed_at) AS hour,
    COUNT(*) AS event_count,
    AVG(processing_time_ms) AS avg_processing_time,
    MAX(processing_time_ms) AS max_processing_time,
    SUM(CASE WHEN success THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN NOT success THEN 1 ELSE 0 END) AS error_count
FROM metrics_event_processing
WHERE processed_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY tenant_id, aggregate_type, event_type, DATE_TRUNC('hour', processed_at);

-- Projection lag current status
CREATE OR REPLACE VIEW metrics_projection_lag_current AS
SELECT DISTINCT ON (projection_name)
    projection_name,
    lag_events,
    lag_seconds,
    measured_at
FROM metrics_projection_lag
ORDER BY projection_name, measured_at DESC;

-- API endpoint stats (last hour)
CREATE OR REPLACE VIEW metrics_api_stats_hourly AS
SELECT 
    endpoint,
    method,
    DATE_TRUNC('hour', requested_at) AS hour,
    COUNT(*) AS request_count,
    AVG(response_time_ms) AS avg_response_time,
    MAX(response_time_ms) AS max_response_time,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95_response_time,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms) AS p99_response_time,
    SUM(CASE WHEN status_code BETWEEN 200 AND 299 THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) AS error_count
FROM metrics_api_requests
WHERE requested_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY endpoint, method, DATE_TRUNC('hour', requested_at);

-- Command execution stats
CREATE OR REPLACE VIEW metrics_command_stats_daily AS
SELECT 
    command_type,
    aggregate_type,
    DATE(requested_at) AS day,
    COUNT(*) AS command_count,
    AVG(execution_time_ms) AS avg_execution_time,
    SUM(CASE WHEN success THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN NOT success THEN 1 ELSE 0 END) AS error_count
FROM metrics_command_execution
WHERE executed_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY command_type, aggregate_type, DATE(requested_at);

-- Saga execution stats
CREATE OR REPLACE VIEW metrics_saga_stats_daily AS
SELECT 
    saga_type,
    DATE(completed_at) AS day,
    COUNT(*) AS total_sagas,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN status = 'compensated' THEN 1 ELSE 0 END) AS compensated_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count,
    AVG(execution_time_ms) AS avg_execution_time
FROM metrics_saga_execution
WHERE completed_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY saga_type, DATE(completed_at);

-- ============================================================================
-- ALERTING FUNCTIONS
-- ============================================================================

-- Check if projection lag exceeds threshold
CREATE OR REPLACE FUNCTION metrics_check_projection_lag(
    p_projection_name VARCHAR(128),
    p_threshold_events BIGINT DEFAULT 1000,
    p_threshold_seconds INT DEFAULT 300
)
RETURNS TABLE (
    is_alerting BOOLEAN,
    lag_events BIGINT,
    lag_seconds INT,
    message TEXT
) AS $$
DECLARE
    v_lag RECORD;
BEGIN
    SELECT * INTO v_lag
    FROM metrics_projection_lag_current
    WHERE projection_name = p_projection_name;
    
    IF v_lag IS NULL THEN
        RETURN QUERY SELECT TRUE, 0::BIGINT, 0, 'No lag data available for ' || p_projection_name;
        RETURN;
    END IF;
    
    IF v_lag.lag_events > p_threshold_events THEN
        RETURN QUERY SELECT TRUE, v_lag.lag_events, v_lag.lag_seconds, 
            'Projection ' || p_projection_name || ' lag exceeds threshold: ' || v_lag.lag_events || ' events';
        RETURN;
    END IF;
    
    IF v_lag.lag_seconds IS NOT NULL AND v_lag.lag_seconds > p_threshold_seconds THEN
        RETURN QUERY SELECT TRUE, v_lag.lag_events, v_lag.lag_seconds,
            'Projection ' || p_projection_name || ' lag exceeds time threshold: ' || v_lag.lag_seconds || ' seconds';
        RETURN;
    END IF;
    
    RETURN QUERY SELECT FALSE, v_lag.lag_events, COALESCE(v_lag.lag_seconds, 0), 
        'Projection ' || p_projection_name || ' is healthy';
END;
$$ LANGUAGE plpgsql;

-- Get system health overview
CREATE OR REPLACE FUNCTION metrics_get_system_health()
RETURNS TABLE (
    component TEXT,
    status TEXT,
    details JSONB
) AS $$
BEGIN
    -- Event store health
    RETURN QUERY
    SELECT 
        'event_store'::TEXT,
        CASE 
            WHEN COUNT(*) > 10000 THEN 'warning'::TEXT
            ELSE 'healthy'::TEXT
        END,
        jsonb_build_object('event_count', COUNT(*), 'oldest_event', MIN(created_at))
    FROM event_store
    WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 hour';
    
    -- Projection health
    RETURN QUERY
    SELECT 
        'projections'::TEXT,
        CASE 
            WHEN MAX(lag_events) > 1000 THEN 'critical'::TEXT
            WHEN MAX(lag_events) > 100 THEN 'warning'::TEXT
            ELSE 'healthy'::TEXT
        END,
        jsonb_agg(jsonb_build_object('name', projection_name, 'lag', lag_events))
    FROM metrics_projection_lag_current;
    
    -- API health
    RETURN QUERY
    SELECT 
        'api'::TEXT,
        CASE 
            WHEN AVG(response_time_ms) > 1000 THEN 'warning'::TEXT
            WHEN SUM(CASE WHEN status_code >= 500 THEN 1 ELSE 0 END) > 10 THEN 'critical'::TEXT
            ELSE 'healthy'::TEXT
        END,
        jsonb_build_object(
            'avg_response_time', AVG(response_time_ms),
            'error_rate', SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0)
        )
    FROM metrics_api_requests
    WHERE requested_at >= CURRENT_TIMESTAMP - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;
