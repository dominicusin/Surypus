-- V344__rbac_canonical_finalization_health_dashboard.sql
-- Produce a structured health dashboard for Prometheus-like consumption
CREATE OR REPLACE FUNCTION rbac.health_dashboard_json() RETURNS JSONB AS $$
DECLARE
  v_inconsistencies INTEGER;
  v_last_run_at TIMESTAMPTZ;
  v_last_run_updated INTEGER;
  v_last_batch_started TIMESTAMPTZ;
  v_last_batch_ended TIMESTAMPTZ;
  v_batch_size INTEGER;
  v_batch_total INTEGER;
  v_batch_status TEXT;
  v_batch_details JSONB;
  v_cb_state VARCHAR(20);
  v_cb_next_attempt TIMESTAMPTZ;
  v_cb_half_open_calls INTEGER;
  v_cb_half_open_max_calls INTEGER;
  v_cb_last_failure TIMESTAMPTZ;
  v_cb_map JSONB;
  v_out JSONB;
BEGIN
  -- Inconsistencies count
  v_inconsistencies := rbac.count_canon_inconsistencies();

  -- Last metrics
  IF EXISTS (SELECT 1 FROM rbac.canon_metrics) THEN
    SELECT run_at, updated_rows, details INTO v_last_run_at, v_last_run_updated, v_batch_details
    FROM rbac.canon_metrics ORDER BY run_at DESC LIMIT 1;
  END IF;

  -- Last batch run
  IF EXISTS (SELECT 1 FROM rbac.canon_batch_runs WHERE ended_at IS NOT NULL) THEN
    SELECT started_at, ended_at, batch_size, total_updated, status, details
    INTO v_last_batch_started, v_last_batch_ended, v_batch_size, v_batch_total, v_batch_status, v_batch_details
    FROM rbac.canon_batch_runs ORDER BY ended_at DESC LIMIT 1;
  END IF;

  -- Circuit breaker state
  SELECT state, next_attempt_time, half_open_calls, half_open_max_calls, last_failure_time
  INTO v_cb_state, v_cb_next_attempt, v_cb_half_open_calls, v_cb_half_open_max_calls, v_cb_last_failure
  FROM rbac.canon_circuit_breaker WHERE id = 1;
  v_cb_map := jsonb_build_object(
    'state', v_cb_state,
    'next_attempt', v_cb_next_attempt,
    'half_open_calls', v_cb_half_open_calls,
    'half_open_max_calls', v_cb_half_open_max_calls,
    'last_failure_time', v_cb_last_failure
  );

  v_out := jsonb_build_object(
    'timestamp', NOW(),
    'consistent', (v_inconsistencies = 0),
    'inconsistencies', v_inconsistencies,
    'last_run', jsonb_build_object('run_at', v_last_run_at, 'updated_rows', v_last_run_updated),
    'last_batch', jsonb_build_object(
      'started_at', v_last_batch_started,
      'ended_at', v_last_batch_ended,
      'batch_size', v_batch_size,
      'total_updated', v_batch_total,
      'status', v_batch_status,
      'details', v_batch_details
    ),
    'circuit_breaker', v_cb_map,
    'status', CASE WHEN v_inconsistencies = 0 THEN 'healthy' ELSE 'unhealthy' END
  );
  RETURN v_out;
END;
$$ LANGUAGE plpgsql;
