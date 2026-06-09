-- Multi-Tenant: RLS Policies
-- Enable RLS and create policies for tenant isolation

-- Helper function to get current tenant_id from session
CREATE OR REPLACE FUNCTION app.current_tenant_id()
RETURNS BIGINT AS $$
  SELECT COALESCE(NULLIF(current_setting('app.tenant_id', TRUE), ''), '0')::BIGINT;
$$ LANGUAGE SQL STABLE;

-- Helper function to get current user_id from session
CREATE OR REPLACE FUNCTION app.current_user_id()
RETURNS BIGINT AS $$
  SELECT COALESCE(NULLIF(current_setting('app.user_id', TRUE), ''), '0')::BIGINT;
$$ LANGUAGE SQL STABLE;

-- Helper function to check if multi-tenant mode is active
CREATE OR REPLACE FUNCTION app.is_multi_tenant()
RETURNS BOOLEAN AS $$
  SELECT current_setting('app.tenant_id', TRUE) != '' AND current_setting('app.tenant_id', TRUE) != '0';
$$ LANGUAGE SQL STABLE;

-- Apply RLS to business tables
-- Each table gets: tenant_id column (if missing), RLS enabled, and a policy

DO $$
DECLARE
  tbl TEXT;
  tables TEXT[] := ARRAY[
    'person', 'goods', 'bill', 'bill_line', 'stock', 'location',
    'employee', 'salary', 'order_head', 'order_line', 'payment',
    'acc_plan', 'acc_turn', 'goods_price', 'report_template',
    'event_store', 'audit_log', 'integrations', 'workflow',
    'workflow_instance', 'tech_card', 'work_order', 'users'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    -- Add tenant_id column if it doesn't exist
    BEGIN
      EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS tenant_id BIGINT NOT NULL DEFAULT 0', tbl);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not add tenant_id to %: %', tbl, SQLERRM;
    END;

    -- Enable RLS
    BEGIN
      EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not enable RLS on %: %', tbl, SQLERRM;
    END;

    -- Create or replace RLS policy
    BEGIN
      EXECUTE format(
        'DROP POLICY IF EXISTS tenant_isolation ON %I',
        tbl
      );
      EXECUTE format(
        'CREATE POLICY tenant_isolation ON %I FOR ALL USING (tenant_id = app.current_tenant_id())',
        tbl
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not create RLS policy on %: %', tbl, SQLERRM;
    END;
  END LOOP;
END;
$$;

-- For multi-tenant admin users who need to see all data
CREATE OR REPLACE FUNCTION app.set_tenant_context(p_tenant_id BIGINT, p_user_id BIGINT DEFAULT 0)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.tenant_id', p_tenant_id::TEXT, TRUE);
  PERFORM set_config('app.user_id', p_user_id::TEXT, TRUE);
END;
$$ LANGUAGE PLPGSQL;

-- Clear tenant context (revert to public/no tenant filtering)
CREATE OR REPLACE FUNCTION app.clear_tenant_context()
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.tenant_id', '', TRUE);
  PERFORM set_config('app.user_id', '', TRUE);
END;
$$ LANGUAGE PLPGSQL;
