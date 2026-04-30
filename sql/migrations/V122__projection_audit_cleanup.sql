-- Periodic cleanup for old projection audit logs (safe-ops)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projection_audit') THEN
    DELETE FROM projection_audit WHERE created_at < NOW() - INTERVAL '180 days';
  END IF;
END $$;
