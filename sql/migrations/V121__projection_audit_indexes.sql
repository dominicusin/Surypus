-- Improve read performance for projection audit logs.
-- Guarded: projection_audit is created by a later migration.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'projection_audit') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_projection_audit_event ON projection_audit(event_type, projection_name)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_projection_audit_created ON projection_audit(created_at)';
  END IF;
END $$;
