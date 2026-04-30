-- V370__rbac_concurrency_allow.sql
-- Enable/disable concurrency exposure for canonicalization
CREATE OR REPLACE FUNCTION rbac.set_concurrency_allowed(_allowed BOOLEAN) RETURNS VOID AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'config') THEN
    -- Use an integer flag for simplicity
    IF _allowed THEN
      PERFORM rbac.set_config_int('canonical_allow_concurrency', 1);
    ELSE
      PERFORM rbac.set_config_int('canonical_allow_concurrency', 0);
    END IF;
  ELSE
    -- Fallback: create config table entry
    PERFORM rbac.set_config_int('canonical_allow_concurrency', CASE WHEN _allowed THEN 1 ELSE 0 END);
  END IF;
END;
$$ LANGUAGE plpgsql;
