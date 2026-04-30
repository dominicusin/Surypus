-- V999__rbac_bridge_wrappers_schema_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'rbac_core') THEN
    PERFORM 1;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac_core' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac_core.canonicalize_all();
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac_core' AND routine_name = 'canonicalize_all_batch') THEN
    PERFORM rbac_core.canonicalize_all_batch(10);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac_core' AND routine_name = 'next_round_robin_table') THEN
    PERFORM rbac_core.next_round_robin_table();
  END IF;
END;
$$ LANGUAGE plpgsql;
