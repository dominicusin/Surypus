-- ============================================================================
-- Phase 5: Domain-Based Organization - Final Consolidation
-- ============================================================================

-- ============================================================================
-- DOMAIN: CORE - Event Sourcing & Projections (already exists in V001)
-- ============================================================================

-- ============================================================================
-- DOMAIN: CORE - Snapshot Management
-- ============================================================================

-- Snapshot policy
CREATE TABLE IF NOT EXISTS snapshot_policies (
    id SERIAL PRIMARY KEY,
    aggregate_type TEXT NOT NULL,
    snapshot_interval INT NOT NULL,  -- events count
    retention_days INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(aggregate_type)
);

-- Create snapshot
CREATE OR REPLACE FUNCTION create_snapshot(
    p_aggregate_type TEXT,
    p_aggregate_id UUID,
    p_state JSONB
) RETURNS BIGINT AS $$
DECLARE
    v_snapshot_id BIGINT;
BEGIN
    INSERT INTO snapshots (aggregate_type, aggregate_id, state, version)
    VALUES (p_aggregate_type, p_aggregate_id, p_state, 0)
    RETURNING id INTO v_snapshot_id;
    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Rebuild from snapshot
CREATE OR REPLACE FUNCTION rebuild_from_snapshot(
    p_aggregate_type TEXT,
    p_aggregate_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_snapshot RECORD;
    v_events JSONB;
BEGIN
    SELECT * INTO v_snapshot 
    FROM snapshots 
    WHERE aggregate_type = p_aggregate_type 
      AND aggregate_id = p_aggregate_id
    ORDER BY version DESC 
    LIMIT 1;

    IF v_snapshot IS NULL THEN
        RETURN NULL;
    END IF;

    v_snapshot.state := v_snapshot.state || jsonb_build_object(
        '_rebuilt_from_snapshot', v_snapshot.id,
        '_rebuilt_at', NOW()::TEXT
    );

    RETURN v_snapshot.state;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOMAIN: INVENTORY - Warehouse & Stock Management
-- ============================================================================

-- Stock movements (enriched)
CREATE TABLE IF NOT EXISTS stock_movements (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL,
    goods_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    movement_type TEXT NOT NULL,  -- RECEIPT, ISSUE, TRANSFER, ADJUSTMENT
    quantity NUMERIC NOT NULL,
    unit_cost NUMERIC,
    document_ref TEXT,
    document_id UUID,
    event_id UUID REFERENCES event_store(id),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_tenant_goods 
ON stock_movements(tenant_id, goods_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_warehouse_date
ON stock_movements(warehouse_id, recorded_at);

-- Stock balance (materialized)
CREATE TABLE IF NOT EXISTS stock_balances (
    tenant_id UUID NOT NULL,
    goods_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    quantity NUMERIC NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (tenant_id, goods_id, warehouse_id)
);

-- Stock balance update function
CREATE OR REPLACE FUNCTION update_stock_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE stock_balances 
        SET quantity = quantity + NEW.quantity,
            updated_at = NOW()
        WHERE tenant_id = NEW.tenant_id 
          AND goods_id = NEW.goods_id 
          AND warehouse_id = NEW.warehouse_id;
        
        IF NOT FOUND THEN
            INSERT INTO stock_balances (tenant_id, goods_id, warehouse_id, quantity)
            VALUES (NEW.tenant_id, NEW.goods_id, NEW.warehouse_id, NEW.quantity);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_movement_update
AFTER INSERT ON stock_movements
FOR EACH ROW EXECUTE FUNCTION update_stock_balance();

-- ============================================================================
-- DOMAIN: ACCOUNTING - Double-Entry Bookkeeping
-- ============================================================================

-- Account chart
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    account_code TEXT NOT NULL,
    account_name TEXT NOT NULL,
    account_type TEXT NOT NULL,  -- ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
    parent_account_id UUID REFERENCES chart_of_accounts(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, account_code)
);

-- Ledger entries
CREATE TABLE IF NOT EXISTS ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    account_id UUID REFERENCES chart_of_accounts(id),
    debit_amount NUMERIC NOT NULL DEFAULT 0,
    credit_amount NUMERIC NOT NULL DEFAULT 0,
    document_type TEXT,
    document_id UUID,
    description TEXT,
    event_id UUID REFERENCES event_store(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_tenant_account
ON ledger_entries(tenant_id, account_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_document
ON ledger_entries(document_type, document_id);

-- Balance validation
CREATE OR REPLACE FUNCTION validate_ledger_balance(
    p_tenant_id UUID,
    p_document_type TEXT,
    p_document_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_debit NUMERIC;
    v_credit NUMERIC;
BEGIN
    SELECT COALESCE(SUM(debit_amount), 0), COALESCE(SUM(credit_amount), 0)
    INTO v_debit, v_credit
    FROM ledger_entries
    WHERE tenant_id = p_tenant_id
      AND document_type = p_document_type
      AND document_id = p_document_id;

    RETURN v_debit = v_credit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOMAIN: TAX - VAT & Tax Calculations
-- ============================================================================

-- Tax rates
CREATE TABLE IF NOT EXISTS tax_rates (
    id SERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL,
    tax_name TEXT NOT NULL,
    tax_rate NUMERIC NOT NULL,  -- percentage
    tax_type TEXT NOT NULL,  -- VAT, EXCISE, CUSTOM
    is_active BOOLEAN DEFAULT TRUE,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tax entries
CREATE TABLE IF NOT EXISTS tax_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    document_type TEXT NOT NULL,
    document_id UUID NOT NULL,
    tax_rate_id INT REFERENCES tax_rates(id),
    taxable_amount NUMERIC NOT NULL,
    tax_amount NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- VAT calculation
CREATE OR REPLACE FUNCTION calc_vat(
    p_amount NUMERIC,
    p_rate NUMERIC
) RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND(p_amount * (p_rate / 100.0), 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- DOMAIN: ORDERS - Bills & Orders
-- ============================================================================

-- Bills
CREATE TABLE IF NOT EXISTS bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    bill_number TEXT NOT NULL,
    bill_type TEXT NOT NULL,  -- SALES, PURCHASE, TRANSFER
    bill_date DATE NOT NULL,
    counterparty_id UUID,
    total_amount NUMERIC NOT NULL DEFAULT 0,
    vat_amount NUMERIC NOT NULL DEFAULT 0,
    status TEXT DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, bill_number)
);

-- Bill lines
CREATE TABLE IF NOT EXISTS bill_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID REFERENCES bills(id) ON DELETE CASCADE,
    goods_id UUID NOT NULL,
    quantity NUMERIC NOT NULL,
    unit_price NUMERIC NOT NULL,
    vat_rate NUMERIC,
    line_total NUMERIC NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_bills_tenant_date
ON bills(tenant_id, bill_date);

-- ============================================================================
-- DOMAIN: GOODS - Product Management
-- ============================================================================

-- Goods catalog
CREATE TABLE IF NOT EXISTS goods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    goods_code TEXT NOT NULL,
    goods_name TEXT NOT NULL,
    unit_of_measure TEXT,
    category_id UUID,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, goods_code)
);

-- Goods categories
CREATE TABLE IF NOT EXISTS goods_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    category_name TEXT NOT NULL,
    parent_category_id UUID REFERENCES goods_categories(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN: PERSONS - Employees & Contacts
-- ============================================================================

-- Persons
CREATE TABLE IF NOT EXISTS persons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    person_type TEXT NOT NULL,  -- EMPLOYEE, CUSTOMER, SUPPLIER
    first_name TEXT,
    last_name TEXT,
    full_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Employee details
CREATE TABLE IF NOT EXISTS employee_details (
    person_id UUID REFERENCES person(id) ON DELETE CASCADE,
    employee_id TEXT UNIQUE,
    department TEXT,
    position TEXT,
    hire_date DATE,
    salary NUMERIC
);

-- ============================================================================
-- DOMAIN: COMPANIES - Multi-Tenant Organization
-- ============================================================================

-- Companies
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    company_code TEXT UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN: RBAC - Unified Access Control
-- ============================================================================

-- Permission registry (unified)
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    permission_name TEXT UNIQUE NOT NULL,
    permission_type TEXT NOT NULL,  -- READ, WRITE, EXECUTE, ADMIN
    resource_type TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Role permissions
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id INT REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id)
);

-- User roles
CREATE TABLE IF NOT EXISTS user_roles_v2 (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(role_id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES tenants(tenant_id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id, tenant_id)
);

-- Unified permission check
CREATE OR REPLACE FUNCTION has_permission_v2(
    p_user_id UUID,
    p_permission_name TEXT,
    p_tenant_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_has_permission BOOLEAN := FALSE;
BEGIN
    IF p_tenant_id IS NOT NULL THEN
        SELECT TRUE INTO v_has_permission
        FROM user_roles_v2 ur
        JOIN role_permissions rp ON rp.role_id = ur.role_id
        JOIN permissions p ON p.id = rp.permission_id
        WHERE ur.user_id = p_user_id
          AND ur.tenant_id = p_tenant_id
          AND p.permission_name = p_permission_name;
    ELSE
        SELECT TRUE INTO v_has_permission
        FROM user_roles ur
        JOIN roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = p_user_id
          AND r.role_name = 'admin';
    END IF;

    RETURN COALESCE(v_has_permission, FALSE);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOMAIN: AUDIT - Complete Audit Trail
-- ============================================================================

-- Audit log
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID,
    user_id UUID,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id TEXT,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_tenant_user
ON audit_log(tenant_id, user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_table_record
ON audit_log(table_name, record_id);

-- Audit trigger helper
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (tenant_id, user_id, action, table_name, new_values)
        VALUES (NEW.tenant_id, NULL, 'INSERT', TG_TABLE_NAME, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (tenant_id, user_id, action, table_name, record_id, old_values, new_values)
        VALUES (NEW.tenant_id, NULL, 'UPDATE', TG_TABLE_NAME, NEW.id::TEXT, to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (tenant_id, user_id, action, table_name, record_id, old_values)
        VALUES (OLD.tenant_id, NULL, 'DELETE', TG_TABLE_NAME, OLD.id::TEXT, to_jsonb(OLD));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOMAIN: TENANT - Multi-Tenant Isolation
-- ============================================================================

-- Tenant configuration
CREATE TABLE IF NOT EXISTS tenant_configs (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(tenant_id),
    config_key TEXT NOT NULL,
    config_value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, config_key)
);

-- Tenant-specific settings
CREATE OR REPLACE FUNCTION get_tenant_config(
    p_tenant_id UUID,
    p_key TEXT,
    p_default JSONB DEFAULT '{}'
) RETURNS JSONB AS $$
DECLARE
    v_value JSONB;
BEGIN
    SELECT config_value INTO v_value
    FROM tenant_configs
    WHERE tenant_id = p_tenant_id AND config_key = p_key;

    RETURN COALESCE(v_value, p_default);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Final Summary
-- ============================================================================

SELECT 'Phase 5 Complete: Domain-based organization finalized' AS status,
       NOW() AS completed_at;