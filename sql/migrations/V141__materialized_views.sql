-- Materialized views for read optimization
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_aggregate_counts AS
SELECT 
    aggregate_type,
    tenant_id,
    COUNT(*) as event_count,
    COUNT(DISTINCT aggregate_id) as unique_aggregates,
    MAX(created_at) as last_event_at
FROM event_store
GROUP BY aggregate_type, tenant_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_aggregate_counts 
ON mv_aggregate_counts(aggregate_type, tenant_id);

-- Refresh-concurrently wrapper
CREATE OR REPLACE FUNCTION refresh_mv_aggregate_counts() RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_aggregate_counts;
END;
$$ LANGUAGE plpgsql;

-- Event type distribution
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_event_type_dist AS
SELECT 
    event_type,
    aggregate_type,
    COUNT(*) as total_events,
    COUNT(DISTINCT tenant_id) as tenant_count
FROM event_store
GROUP BY event_type, aggregate_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_event_type_dist ON mv_event_type_dist(event_type);