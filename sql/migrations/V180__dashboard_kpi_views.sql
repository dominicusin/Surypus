-- ============================================================================
-- Dashboard KPI Materialized Views
-- ============================================================================
-- These KPIs read the domain tables (bills/goods/persons). The legacy core
-- schema created in V001 has a different (smaller) bills shape and uses the
-- singular `person` table, so each MV is guarded: it is built only when the
-- underlying table AND all required columns actually exist. refresh_all_mv
-- tolerates missing views (it just skips refresh for any that don't exist).

-- Revenue KPI: monthly revenue by bill type and status
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills')
     AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='bills' AND column_name IN ('tenant_id','bill_date','bill_type','status','total_amount','vat_amount')) = 6
  THEN
    EXECUTE 'CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_revenue AS
      SELECT tenant_id, DATE_TRUNC(''month'', bill_date) as month, bill_type, status,
             COUNT(*) as bill_count, SUM(total_amount) as revenue_total,
             SUM(vat_amount) as vat_total, SUM(total_amount - vat_amount) as net_total,
             MIN(bill_date) as first_bill_date, MAX(bill_date) as last_bill_date
      FROM bills GROUP BY tenant_id, DATE_TRUNC(''month'', bill_date), bill_type, status';
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_revenue ON mv_dashboard_revenue(tenant_id, month, bill_type, status)';
  END IF;
END $$;

-- Orders KPI: order counts by status
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills')
     AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='bills' AND column_name IN ('tenant_id','status','bill_type','total_amount')) = 4
  THEN
    EXECUTE 'CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_orders AS
      SELECT tenant_id, status, bill_type, COUNT(*) as order_count, SUM(total_amount) as total_value
      FROM bills GROUP BY tenant_id, status, bill_type';
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_orders ON mv_dashboard_orders(tenant_id, status, bill_type)';
  END IF;
END $$;

-- Stock KPI: stock summary
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'goods')
     AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='goods' AND column_name IN ('tenant_id','is_active','category_id')) = 3
  THEN
    EXECUTE 'CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_stock AS
      SELECT g.tenant_id, COUNT(*) as total_goods,
             SUM(CASE WHEN g.is_active THEN 1 ELSE 0 END) as active_goods,
             COUNT(DISTINCT g.category_id) as category_count
      FROM goods g GROUP BY g.tenant_id';
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_stock ON mv_dashboard_stock(tenant_id)';
  END IF;
END $$;

-- Partners KPI: person/partner counts by type
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'persons')
     AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='persons' AND column_name IN ('tenant_id','person_type','is_active')) = 3
  THEN
    EXECUTE 'CREATE MATERIALIZED VIEW IF NOT EXISTS mv_dashboard_partners AS
      SELECT tenant_id, person_type, COUNT(*) as person_count,
             SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_count
      FROM persons GROUP BY tenant_id, person_type';
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_partners ON mv_dashboard_partners(tenant_id, person_type)';
  END IF;
END $$;

-- ============================================================================
-- Update refresh function to include new views
-- ============================================================================
CREATE OR REPLACE FUNCTION refresh_all_mv() RETURNS VOID AS $$
BEGIN
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_aggregate_counts; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_event_type_dist; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_event_trends; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_activity; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_state; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_bill_state; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_dashboard; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_revenue; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_orders; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_stock; EXCEPTION WHEN OTHERS THEN END;
    BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_partners; EXCEPTION WHEN OTHERS THEN END;
    RAISE NOTICE 'All materialized views refreshed';
END;
$$ LANGUAGE plpgsql;
