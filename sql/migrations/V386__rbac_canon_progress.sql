-- V386__rbac_canon_progress.sql
-- Produce a current snapshot of canonicalization progress as JSON
CREATE OR REPLACE FUNCTION rbac.canon_progress() RETURNS JSONB AS $$
DECLARE
  pending_count INTEGER;
  inprogress_count INTEGER;
  completed_batches INTEGER;
  last_run TIMESTAMPTZ;
  last_run_updated INTEGER;
  last_batch_id BIGINT;
  last_batch_size BIGINT;
  last_batch_started TIMESTAMPTZ;
  last_batch_ended TIMESTAMPTZ;
  last_status TEXT;
  last_details JSONB;
  details JSONB;
BEGIN
  SELECT count(*) INTO pending_count FROM rbac.canon_queue WHERE status = 'pending';
  SELECT count(*) INTO inprogress_count FROM rbac.canon_queue WHERE status = 'in_progress';
  SELECT count(*) INTO completed_batches FROM rbac.canon_batch_runs WHERE ended_at IS NOT NULL;
  SELECT run_at, updated_rows, details INTO last_run, last_run_updated, details FROM rbac.canon_metrics ORDER BY run_at DESC LIMIT 1;
  SELECT id, started_at, ended_at, batch_size, total_updated, status, details INTO last_batch_id, last_batch_started, last_batch_ended, last_batch_size, last_run_updated, last_status, last_details FROM rbac.canon_batch_runs ORDER BY ended_at DESC LIMIT 1;
  RETURN jsonb_build_object(
    'snapshot', jsonb_build_object(
      'pending', pending_count,
      'in_progress', inprogress_count,
      'completed_batches', completed_batches
    ),
    'last_run', jsonb_build_object('run_at', COALESCE(last_run, NOW()), 'updated', last_run_updated, 'details', details),
    'last_batch', jsonb_build_object('began', last_batch_started, 'ended', last_batch_ended, 'batch_id', last_batch_id, 'updated', last_run_updated)
  );
END;
$$ LANGUAGE plpgsql;
