-- V410__rbac_canon_progress_merge_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'merge_progress') THEN
    -- test basic merge
    IF (SELECT rbac.merge_progress('[{"a":1}]'::jsonb, '[{"b":2}]'::jsonb)) IS NULL THEN
      RAISE EXCEPTION 'merge progressed returned NULL';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
