-- V434__rbac_ci_integration.sql
-- CI integration helpers (migrations & tests) for automated validation
CREATE OR REPLACE FUNCTION rbac.ci_validate_migrations() RETURNS TEXT AS $$
BEGIN
  -- Placeholder: in CI this would run a dry-run of migrations and return summary
  RETURN 'CI validation ready';
END;
$$ LANGUAGE plpgsql;
