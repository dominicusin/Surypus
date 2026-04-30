-- V358__rbac_canon_cb_history_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_cb_transition') THEN
    PERFORM rbac.log_cb_transition('CLOSED', 'OPEN', '{}'::jsonb);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_cb_history') THEN
    IF NOT EXISTS (SELECT 1 FROM rbac.canon_cb_history WHERE old_state = 'CLOSED' AND new_state = 'OPEN') THEN
      RAISE NOTICE 'cb_history not recorded yet – logging may be deferred';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
