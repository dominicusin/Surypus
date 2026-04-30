-- V341__rbac_canonical_finalize_table_patch_test.sql
DO $$
DECLARE
  v_cnt INTEGER := 0;
BEGIN
  -- If the table canon_metrics exists, patch it
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='rbac' AND table_name='canon_metrics') THEN
    v_cnt := rbac.canonicalize_table('rbac', 'canon_metrics');
    -- v_cnt may be 0 if nothing needed
    IF v_cnt < 0 THEN
      RAISE EXCEPTION 'unexpected negative count from canonicalize_table';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
