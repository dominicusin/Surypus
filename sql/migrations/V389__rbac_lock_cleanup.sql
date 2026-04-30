-- V389__rbac_lock_cleanup.sql
-- Cleanup old lock records (if any)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_lock_attempts') THEN
    -- Keep last 1000 attempts, delete older ones
    DELETE FROM rbac.canon_lock_attempts
    WHERE id < (SELECT id FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY attempted_at DESC) AS rn FROM rbac.canon_lock_attempts) t WHERE t.rn = 1000);
  END IF;
END;
$$ LANGUAGE plpgsql;
