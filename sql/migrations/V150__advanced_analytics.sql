-- Advanced analytics: event trends
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_event_trends AS
SELECT 
    DATE_TRUNC('day', created_at) as day,
    aggregate_type,
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT aggregate_id) as unique_aggregates,
    COUNT(DISTINCT tenant_id) as active_tenants
FROM event_store
GROUP BY DATE_TRUNC('day', created_at), aggregate_type, event_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_event_trends 
ON mv_event_trends(day, aggregate_type, event_type);

-- Tenant activity summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_tenant_activity AS
SELECT 
    tenant_id,
    DATE_TRUNC('day', created_at) as day,
    COUNT(*) as events,
    COUNT(DISTINCT aggregate_id) as aggregates,
    COUNT(DISTINCT user_id) as active_users
FROM event_store
GROUP BY tenant_id, DATE_TRUNC('day', created_at);

CREATE INDEX IF NOT EXISTS idx_mv_tenant_activity ON mv_tenant_activity(tenant_id, day DESC);

-- Refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_all_mv() RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_aggregate_counts;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_event_type_dist;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_event_trends;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_activity;
    RAISE NOTICE 'All materialized views refreshed';
END;
$$ LANGUAGE plpgsql;