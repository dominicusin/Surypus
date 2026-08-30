-- ============================================================================
-- CRM Schema: Companies, Contacts, Pipeline Rules, Stage History
-- ============================================================================
-- Creates tables referenced by V181 (companies(id)) and adds new CRM entities.
-- Each table includes bigint_event_id BIGSERIAL for event store compatibility.
-- ============================================================================

BEGIN;

-- Companies
CREATE TABLE IF NOT EXISTS crm_companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    company_name TEXT NOT NULL,
    person_id BIGINT REFERENCES person(id),
    email TEXT,
    phone TEXT,
    website TEXT,
    industry TEXT,
    size TEXT,
    annual_revenue NUMERIC NOT NULL DEFAULT 0,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    bigint_event_id BIGSERIAL
);

CREATE INDEX IF NOT EXISTS idx_crm_companies_tenant ON crm_companies(tenant_id);
CREATE INDEX IF NOT EXISTS idx_crm_companies_name ON crm_companies(company_name);
CREATE UNIQUE INDEX IF NOT EXISTS idx_crm_companies_tenant_name ON crm_companies(tenant_id, company_name);

-- Contacts
CREATE TABLE IF NOT EXISTS crm_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    mobile_phone TEXT,
    position TEXT,
    company_id UUID REFERENCES crm_companies(id) ON DELETE SET NULL,
    person_id BIGINT REFERENCES person(id),
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    bigint_event_id BIGSERIAL
);

CREATE INDEX IF NOT EXISTS idx_crm_contacts_tenant ON crm_contacts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_company ON crm_contacts(company_id);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_name ON crm_contacts(last_name, first_name);

-- Pipeline stage entry/exit criteria rules
CREATE TABLE IF NOT EXISTS crm_pipeline_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stage_id UUID REFERENCES crm_pipeline_stages(id) ON DELETE CASCADE,
    rule_type TEXT NOT NULL CHECK(rule_type IN ('entry', 'exit')),
    criteria_type TEXT NOT NULL,
    criteria_config JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_pipeline_rules_stage ON crm_pipeline_rules(stage_id);

-- Deal stage transition history
CREATE TABLE IF NOT EXISTS crm_deal_stage_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deal_id UUID REFERENCES crm_deals(id) ON DELETE CASCADE,
    from_stage_id UUID REFERENCES crm_pipeline_stages(id),
    to_stage_id UUID REFERENCES crm_pipeline_stages(id) NOT NULL,
    changed_by BIGINT,
    reason TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_stage_history_deal ON crm_deal_stage_history(deal_id);
CREATE INDEX IF NOT EXISTS idx_crm_stage_history_at ON crm_deal_stage_history(changed_at);

COMMIT;
