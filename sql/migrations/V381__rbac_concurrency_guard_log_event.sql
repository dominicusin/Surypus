-- V381__rbac_concurrency_guard_log_event.sql
-- Extend guard logging by recording per-table lock attempts
CREATE OR REPLACE FUNCTION rbac.log_concurrency_guard_event(_slot BIGINT, _schema TEXT, _table TEXT, _attempted BOOLEAN, _success BOOLEAN, _reason TEXT DEFAULT NULL) RETURNS VOID AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_lock_attempts') THEN
    INSERT INTO rbac.canon_lock_attempts (slot, schema_name, table_name, attempted, success, reason)
    VALUES (_slot, _schema, _table, _attempted, _success, _reason);
  END IF;
END;
$$ LANGUAGE plpgsql;
