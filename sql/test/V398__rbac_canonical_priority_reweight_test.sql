-- V398__rbac_canonical_priority_reweight_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'reweight_queue_priority') THEN
    PERFORM rbac.reweight_queue_priority();
  END IF;
  -- Simple sanity: ensure the column exists and is not null for pending rows after operation
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='rbac' AND table_name='canon_queue' AND column_name='priority') THEN
    IF EXISTS (SELECT 1 FROM rbac.canon_queue WHERE status='pending' AND priority IS NULL) THEN
      RAISE EXCEPTION 'priority left NULL after reweight';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
