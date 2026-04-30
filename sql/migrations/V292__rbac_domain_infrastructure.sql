-- Phase 6.2: Lightweight domain infrastructure glue for RBAC (placeholder)
CREATE OR REPLACE FUNCTION rbac_domain_infra(p_tenant_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('tenant', p_tenant_id, 'scope', 'inventory');
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN RAISE NOTICE 'rbac_domain_infra ready'; END $$;
