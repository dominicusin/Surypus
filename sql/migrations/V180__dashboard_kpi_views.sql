-- ============================================================================
-- Dashboard KPI Materialized Views
-- ============================================================================

-- Revenue KPI: monthly revenue by bill type and status
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_revenue AS
SELECT
    tenant_id,
    DATE_TRUNC('month', bill_date) as month,
    bill_type,
    status,
    COUNT(*) as bill_count,
    SUM(total_amount) as revenue_total,
    SUM(vat_amount) as vat_total,
    SUM(total_amount - vat_amount) as net_total,
    MIN(bill_date) as first_bill_date,
    MAX(bill_date) as last_bill_date
FROM bills
GROUP BY tenant_id, DATE_TRUNC('month', bill_date), bill_type, status;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_revenue
ON mv_dashboard_revenue(tenant_id, month, bill_type, status);

-- Orders KPI: order counts by status
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_orders AS
SELECT
    tenant_id,
    status,
    bill_type,
    COUNT(*) as order_count,
    SUM(total_amount) as total_value
FROM bills
GROUP BY tenant_id, status, bill_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_orders
ON mv_dashboard_orders(tenant_id, status, bill_type);

-- Stock KPI: stock summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_stock AS
SELECT
    g.tenant_id,
    COUNT(*) as total_goods,
    SUM(CASE WHEN g.is_active THEN 1 ELSE 0 END) as active_goods,
    COUNT(DISTINCT g.category_id) as category_count
FROM goods g
GROUP BY g.tenant_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_stock
ON mv_dashboard_stock(tenant_id);

-- Partners KPI: person/partner counts by type
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_partners AS
SELECT
    tenant_id,
    person_type,
    COUNT(*) as person_count,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_count
FROM persons
GROUP BY tenant_id, person_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_partners
ON mv_dashboard_partners(tenant_id, person_type);

-- ============================================================================
-- Update refresh function to include new views
-- ============================================================================

CREATE OR REPLACE FUNCTION refresh_all_mv() RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_aggregate_counts;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_event_type_dist;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_event_trends;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_activity;

    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_state;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_bill_state;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_dashboard;

    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_revenue;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_orders;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_stock;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_partners;

    RAISE NOTICE 'All materialized views refreshed';
END;
$$ LANGUAGE plpgsql;
