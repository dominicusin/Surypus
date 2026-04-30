-- Health check and metrics aggregation
CREATE TABLE IF NOT EXISTS health_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    check_name TEXT NOT NULL,
    status TEXT CHECK (status IN ('healthy', 'degraded', 'failed')),
    value NUMERIC,
    message TEXT,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(check_name, recorded_at)
);

-- Function to record health check
CREATE OR REPLACE FUNCTION health_record(
    p_check_name TEXT,
    p_status TEXT,
    p_value NUMERIC DEFAULT NULL,
    p_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO health_metrics (check_name, status, value, message, recorded_at)
    VALUES (p_check_name, p_status, p_value, p_message, CURRENT_TIMESTAMP)
    ON CONFLICT (check_name, recorded_at) DO UPDATE SET
        status = p_status, value = p_value, message = p_message;
END;
$$ LANGUAGE plpgsql;

-- Initial health checks
DO $$ BEGIN
    -- Event store check
    PERFORM health_record('event_store', 'healthy', 
        (SELECT COUNT(*)::NUMERIC FROM event_store));
    -- Outbox check
    PERFORM health_record('outbox_pending', 'healthy',
        (SELECT COUNT(*)::NUMERIC FROM event_outbox WHERE published = FALSE));
    -- DLQ check
    PERFORM health_record('dlq_unresolved', 'healthy',
        (SELECT COUNT(*)::NUMERIC FROM event_dlq WHERE resolved = FALSE));
END $$;