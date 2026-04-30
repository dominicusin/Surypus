-- ============================================================================
-- Data Warehouse Integration
-- ============================================================================

-- Star schema support: Dimension tables
CREATE TABLE IF NOT EXISTS dim_dates (
    date_key DATE PRIMARY KEY,
    day_of_week INT,
    day_name TEXT,
    week_of_year INT,
    month INT,
    month_name TEXT,
    quarter INT,
    year INT,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN
);

-- Populate date dimension
INSERT INTO dim_dates (date_key, day_of_week, day_name, week_of_year, month, month_name, quarter, year, is_weekend, is_holiday)
SELECT 
    d::DATE,
    EXTRACT(DOW FROM d)::INT,
    TO_CHAR(d, 'Day'),
    EXTRACT(WEEK FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'Month'),
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(DOW FROM d) IN (0, 6),
    FALSE
FROM generate_series(CURRENT_DATE - 3650, CURRENT_DATE + 365, '1 day') d
ON CONFLICT (date_key) DO NOTHING;

-- Fact table for analytics
CREATE TABLE IF NOT EXISTS fact_events (
    id BIGSERIAL PRIMARY KEY,
    event_date_key DATE REFERENCES dim_dates(date_key),
    tenant_id UUID,
    aggregate_type TEXT,
    event_type TEXT,
    hour_of_day INT,
    count INT DEFAULT 1,
    unique_aggregates INT DEFAULT 1
);

-- Aggregate to fact table
CREATE OR REPLACE FUNCTION refresh_fact_events() RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    INSERT INTO fact_events (event_date_key, tenant_id, aggregate_type, event_type, hour_of_day, count, unique_aggregates)
    SELECT 
        e.created_at::DATE,
        e.tenant_id,
        e.aggregate_type,
        e.event_type,
        EXTRACT(HOUR FROM e.created_at)::INT,
        COUNT(*),
        COUNT(DISTINCT e.aggregate_id)
    FROM event_store e
    WHERE e.created_at > COALESCE((SELECT MAX(event_date_key) FROM fact_events), '1970-01-01')
    GROUP BY e.created_at::DATE, e.tenant_id, e.aggregate_type, e.event_type, EXTRACT(HOUR FROM e.created_at)
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Analytics aggregation view
CREATE OR REPLACE VIEW v_analytics_daily AS
SELECT 
    fd.date_key,
    fd.day_name,
    fd.month_name,
    fd.quarter,
    fe.aggregate_type,
    fe.event_type,
    SUM(fe.count) as total_events,
    SUM(fe.unique_aggregates) as unique_aggregates,
    COUNT(*) as hourly_buckets
FROM fact_events fe
JOIN dim_dates fd ON fe.event_date_key = fd.date_key
GROUP BY fd.date_key, fd.day_name, fd.month_name, fd.quarter, fe.aggregate_type, fe.event_type;