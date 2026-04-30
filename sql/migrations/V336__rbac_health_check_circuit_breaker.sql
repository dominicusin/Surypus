-- V336__rbac_health_check_circuit_breaker.sql
-- Extend detailed health check to include circuit breaker status
CREATE OR REPLACE FUNCTION rbac.canon_health_detailed()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::jsonb;
    v_inconsistencies INTEGER;
    v_consistent BOOLEAN;
    v_latest_metrics RECORD;
    v_latest_event RECORD;
    v_latest_batch RECORD;
    v_lock_held BOOLEAN;
    v_cb_state VARCHAR(20);
    v_cb_failure_count INTEGER;
    v_cb_last_failure_time TIMESTAMPTZ;
    v_cb_next_attempt_time TIMESTAMPTZ;
    v_cb_half_open_calls INTEGER;
    v_cb_half_open_max_calls INTEGER;
BEGIN
    -- Check consistency
    v_inconsistencies := rbac.count_canon_inconsistencies();
    v_consistent := (v_inconsistencies = 0);
    
    -- Get latest metrics
    SELECT * INTO v_latest_metrics
    FROM rbac.canon_metrics
    ORDER BY run_at DESC
    LIMIT 1;
    
    -- Get latest event
    SELECT * INTO v_latest_event
    FROM rbac.canon_events
    ORDER BY run_at DESC
    LIMIT 1;
    
    -- Get latest completed batch
    SELECT * INTO v_latest_batch
    FROM rbac.canon_batch_runs
    WHERE ended_at IS NOT NULL
    ORDER BY ended_at DESC
    LIMIT 1;
    
    -- Check if advisory lock is currently held (simplified check)
    v_lock_held := FALSE; -- Placeholder - would need actual lock check implementation
    
    -- Get circuit breaker status
    SELECT state, failure_count, last_failure_time, next_attempt_time, half_open_calls,
           (SELECT half_open_max_calls FROM rbac.canon_circuit_breaker WHERE id = 1)
    INTO v_cb_state, v_cb_failure_count, v_cb_last_failure_time, v_cb_next_attempt_time, v_cb_half_open_calls, v_cb_half_open_max_calls
    FROM rbac.canon_circuit_breaker WHERE id = 1;
    
    -- Build comprehensive health status
    v_result := jsonb_build_object(
        'timestamp', NOW(),
        'consistent', v_consistent,
        'inconsistency_count', v_inconsistencies,
        'last_metrics_run',
            CASE WHEN v_latest_metrics IS NOT NULL THEN
                jsonb_build_object(
                    'run_at', v_latest_metrics.run_at,
                    'updated_rows', v_latest_metrics.updated_rows,
                    'details', v_latest_metrics.details
                )
            ELSE
                'null'::jsonb
            END,
        'last_event',
            CASE WHEN v_latest_event IS NOT NULL THEN
                jsonb_build_object(
                    'run_at', v_latest_event.run_at,
                    'table_schema', v_latest_event.table_schema,
                    'table_name', v_latest_event.table_name,
                    'updated', v_latest_event.updated
                )
            ELSE
                'null'::jsonb
            END,
        'last_batch_run',
            CASE WHEN v_latest_batch IS NOT NULL THEN
                jsonb_build_object(
                    'started_at', v_latest_batch.started_at,
                    'ended_at', v_latest_batch.ended_at,
                    'batch_size', v_latest_batch.batch_size,
                    'total_updated', v_latest_batch.total_updated,
                    'status', v_latest_batch.status,
                    'details', v_latest_batch.details
                )
            ELSE
                'null'::jsonb
            END,
        'lock_held_approx', v_lock_held,
        'circuit_breaker',
            jsonb_build_object(
                'state', v_cb_state,
                'failure_count', v_cb_failure_count,
                'last_failure_time', v_cb_last_failure_time,
                'next_attempt_time', v_cb_next_attempt_time,
                'half_open_calls', v_cb_half_open_calls,
                'half_open_max_calls', v_cb_half_open_max_calls
            ),
        'status', CASE WHEN v_consistent AND v_cb_state = 'CLOSED' THEN 'healthy' ELSE 'unhealthy' END
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;