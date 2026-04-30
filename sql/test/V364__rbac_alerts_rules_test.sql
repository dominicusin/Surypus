-- V364__rbac_alerts_rules_test.sql
DO $$
BEGIN
  -- Placeholder test; ensure patch applies
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_health') THEN
    RAISE NOTICE 'Alerting scaffolding ready';
  END IF;
END;
$$ LANGUAGE plpgsql;
