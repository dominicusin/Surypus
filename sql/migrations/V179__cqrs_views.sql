-- ============================================================================
-- CQRS Read Models
-- ============================================================================

-- Inventory read model
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_inventory_state AS
SELECT 
    a.aggregate_id,
    a.tenant_id,
    a.aggregate_type,
    a.current_version,
    a.event_count,
    (SELECT jsonb_object_agg(e.key, e.value) FROM 
        (SELECT e.key, e.value FROM 
            (SELECT jsonb_each(e.event_data) FROM event_store e 
             WHERE e.aggregate_id = a.aggregate_id AND e.event_type IN ('LotCreated', 'StockReceived')
             ORDER BY e.event_version DESC LIMIT 1) t1,
            jsonb_each_text(t1.event_data) 
        ) e
    ) as latest_data,
    MAX(e.created_at) as last_event,
    COUNT(DISTINCT CASE WHEN e.event_type = 'LotCreated' THEN e.event_id END) as lots_created,
    COUNT(DISTINCT CASE WHEN e.event_type = 'LotConsumed' THEN e.event_id END) as lots_consumed
FROM aggregates a
LEFT JOIN event_store e ON e.aggregate_id = a.aggregate_id
WHERE a.aggregate_type = 'Inventory'
GROUP BY a.aggregate_id, a.tenant_id, a.aggregate_type, a.current_version, a.event_count;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_inventory_state ON mv_inventory_state(aggregate_id);

-- Bill read model
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_bill_state AS
SELECT 
    a.aggregate_id,
    a.tenant_id,
    a.current_version,
    (SELECT COUNT(*) FROM event_store e WHERE e.aggregate_id = a.aggregate_id AND e.event_type = 'BillLineAdded') as line_count,
    (SELECT SUM((e.event_data->>'amount')::NUMERIC) FROM event_store e 
     WHERE e.aggregate_id = a.aggregate_id AND e.event_type = 'BillLineAdded') as total_amount,
    MAX(e.created_at) as last_activity,
    COUNT(e.event_id) as event_count
FROM aggregates a
LEFT JOIN event_store e ON e.aggregate_id = a.aggregate_id
WHERE a.aggregate_type = 'Bill'
GROUP BY a.aggregate_id, a.tenant_id, a.current_version;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_bill_state ON mv_bill_state(aggregate_id);

-- Tenant summary read model
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_tenant_dashboard AS
SELECT 
    t.tenant_id,
    t.tenant_name,
    COUNT(DISTINCT a.aggregate_id) as total_aggregates,
    SUM(a.event_count) as total_events,
    COUNT(DISTINCT e.user_id) as active_users,
    MAX(e.created_at) as last_event,
    COUNT(DISTINCT CASE WHEN e.created_at > NOW() - INTERVAL '1 day' THEN e.aggregate_id END) as active_aggregates_24h,
    (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
    (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as dlq_count
FROM tenants t
LEFT JOIN aggregates a ON a.tenant_id = t.tenant_id
LEFT JOIN event_store e ON e.tenant_id = t.tenant_id
GROUP BY t.tenant_id, t.tenant_name;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_tenant_dashboard ON mv_tenant_dashboard(tenant_id);

-- Refresh all CQRS views
CREATE OR REPLACE FUNCTION refresh_cqrs_views() RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_state;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_bill_state;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_dashboard;
    RAISE NOTICE 'CQRS views refreshed';
END;
$$ LANGUAGE plpgsql;