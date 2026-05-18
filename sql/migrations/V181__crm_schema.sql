-- ============================================================================
-- CRM Schema: Deals, Pipeline Stages, Activities
-- ============================================================================

-- Pipeline stages definition
CREATE TABLE IF NOT EXISTS crm_pipeline_stages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    stage_name TEXT NOT NULL,
    stage_order INT NOT NULL,
    stage_probability NUMERIC NOT NULL DEFAULT 0,
    stage_color TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deals
CREATE TABLE IF NOT EXISTS crm_deals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    deal_name TEXT NOT NULL,
    deal_value NUMERIC NOT NULL DEFAULT 0,
    stage_id UUID REFERENCES crm_pipeline_stages(id),
    person_id UUID REFERENCES persons(id),
    company_id UUID REFERENCES companies(id),
    contact_id UUID,
    owner_id UUID,
    expected_close_date DATE,
    priority TEXT DEFAULT 'MEDIUM',
    probability NUMERIC DEFAULT 0,
    notes TEXT,
    tags TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_deals_stage ON crm_deals(stage_id);
CREATE INDEX IF NOT EXISTS idx_crm_deals_tenant ON crm_deals(tenant_id);

-- Activities (calls, meetings, notes)
CREATE TABLE IF NOT EXISTS crm_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    deal_id UUID REFERENCES crm_deals(id) ON DELETE CASCADE,
    person_id UUID REFERENCES persons(id),
    activity_type TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT,
    activity_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_activities_deal ON crm_activities(deal_id);

-- Default pipeline stages
INSERT INTO crm_pipeline_stages (tenant_id, stage_name, stage_order, stage_probability, stage_color) VALUES
    ('00000000-0000-0000-0000-000000000000', 'Lead', 1, 10, '#6c757d'),
    ('00000000-0000-0000-0000-000000000000', 'Qualified', 2, 25, '#0d6efd'),
    ('00000000-0000-0000-0000-000000000000', 'Proposal', 3, 50, '#ffc107'),
    ('00000000-0000-0000-0000-000000000000', 'Negotiation', 4, 75, '#fd7e14'),
    ('00000000-0000-0000-0000-000000000000', 'Closed Won', 5, 100, '#198754'),
    ('00000000-0000-0000-0000-000000000000', 'Closed Lost', 6, 0, '#dc3545')
ON CONFLICT DO NOTHING;

-- Materialized view for pipeline forecasting
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_crm_pipeline_forecast AS
SELECT
    d.tenant_id,
    s.stage_name,
    s.stage_order,
    s.stage_probability,
    COUNT(*) as deal_count,
    SUM(d.deal_value) as pipeline_value,
    SUM(d.deal_value * s.stage_probability / 100) as weighted_forecast
FROM crm_deals d
JOIN crm_pipeline_stages s ON d.stage_id = s.id
WHERE d.is_active AND d.stage_id NOT IN (
    SELECT id FROM crm_pipeline_stages WHERE stage_name IN ('Closed Won', 'Closed Lost')
)
GROUP BY d.tenant_id, s.stage_name, s.stage_order, s.stage_probability;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_crm_forecast
ON mv_crm_pipeline_forecast(tenant_id, stage_name);
