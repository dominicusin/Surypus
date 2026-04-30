-- V324__rbac_canonical_finalization_cleanup.sql
-- Simple cleanup routine for old canonicalization metrics
CREATE OR REPLACE FUNCTION rbac.purge_old_canon_metrics(days INTEGER DEFAULT 30) RETURNS VOID AS $$
BEGIN
  IF days IS NULL THEN days := 30; END IF;
  EXECUTE format('DELETE FROM rbac.canon_metrics WHERE run_at < now() - interval ''%s days''', days);
END;
$$ LANGUAGE plpgsql;
