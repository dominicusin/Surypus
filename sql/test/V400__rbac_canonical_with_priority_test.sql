-- V400__rbac_canonical_with_priority_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_with_priority') THEN
    PERFORM rbac.canonicalize_all_with_priority(5);
  END IF;
END;
$$ LANGUAGE plpgsql;
