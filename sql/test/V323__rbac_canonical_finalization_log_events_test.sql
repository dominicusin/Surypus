-- V323__rbac_canonical_finalization_log_events_test.sql
-- Validate that log_canon_event inserts into canon_events
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_canon_event') THEN
    PERFORM rbac.log_canon_event('rbac','canon_events', 2);
    IF NOT EXISTS (SELECT 1 FROM rbac.canon_events WHERE table_schema='rbac' AND table_name='canon_events' AND updated=2) THEN
      RAISE EXCEPTION 'Canon event log insert failed';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
