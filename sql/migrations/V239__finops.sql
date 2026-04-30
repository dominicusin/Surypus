-- ============================================================================
-- Advanced Cost Optimization & FinOps
-- ============================================================================

-- Cost center allocation
CREATE TABLE IF NOT EXISTS cost_centers (
    id SERIAL PRIMARY KEY,
    center_name TEXT UNIQUE NOT NULL,
    center_code TEXT NOT NULL,
    budget_amount NUMERIC,
    is_active BOOLEAN DEFAULT TRUE
);

-- Cost attribution
CREATE TABLE IF NOT EXISTS cost_attributions (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(tenant_id),
    cost_center_id INT REFERENCES cost_centers(id),
    cost_type TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    attribution_date DATE DEFAULT CURRENT_DATE,
    metadata JSONB DEFAULT '{}'
);

-- Resource optimization recommendations
CREATE TABLE IF NOT EXISTS cost_recommendations (
    id SERIAL PRIMARY KEY,
    recommendation_type TEXT NOT NULL,
    potential_savings NUMERIC,
    implementation_effort TEXT,
    description TEXT,
    is_implemented BOOLEAN DEFAULT FALSE
);

-- Default cost centers
INSERT INTO cost_centers (center_name, center_code, budget_amount)
VALUES 
    ('Production', 'PROD', 100000),
    ('Development', 'DEV', 10000),
    ('Analytics', 'ANLYT', 50000)
ON CONFLICT (center_name) DO NOTHING;

-- Calculate cost by center
CREATE OR REPLACE FUNCTION calculate_cost_by_center(
    p_cost_center_id INT,
    p_start_date DATE,
    p_end_date DATE
) RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_total
    FROM cost_attributions
    WHERE cost_center_id = p_cost_center_id
      AND attribution_date BETWEEN p_start_date AND p_end_date;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- Get optimization recommendations
CREATE OR REPLACE FUNCTION get_cost_recommendations()
RETURNS TABLE(id INT, recommendation_type TEXT, potential_savings NUMERIC, description TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT cr.id, cr.recommendation_type, cr.potential_savings, cr.description
    FROM cost_recommendations cr
    WHERE cr.is_implemented = FALSE
    ORDER BY cr.potential_savings DESC;
END;
$$ LANGUAGE plpgsql;