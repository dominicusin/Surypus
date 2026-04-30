-- Phase 6: runtime checks (RBAC + projection wiring)
CREATE OR REPLACE FUNCTION validate_rbac_and_projection_ready()
RETURNS BOOLEAN AS $$
DECLARE
  v_has_perm BOOLEAN;
  v_trg_exists BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_permission_compat') INTO v_has_perm;
  SELECT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_proc p ON t.tgfoid = p.oid WHERE tgname = 'trg_event_to_projection') INTO v_trg_exists;
  RETURN v_has_perm AND v_trg_exists;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN IF NOT validate_rbac_and_projection_ready() THEN RAISE NOTICE 'RBAC or projection wiring not ready'; END IF; END; $$;
