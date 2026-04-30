-- Lock monitoring view
CREATE OR REPLACE VIEW v_active_locks AS
SELECT 
    pg.blocking_locks.locktype,
    pg.blocking_locks.relation::regclass as table_name,
    pg.blocking_locks.mode,
    pg.blocking_locks.granted,
    pg.blocking_locks.pid,
    pg.blocking_locks.username,
    pg.blocking_locks.query
FROM pg_locks pg
WHERE NOT pg.locksrelation IS NULL
ORDER BY pg.blocking_locks.granted, pg.blocking_locks.pid;

-- Long-running query detection
CREATE OR REPLACE VIEW v_long_queries AS
SELECT 
    pid,
    usename,
    query,
    state,
    wait_event_type,
    wait_event,
    backend_start,
    query_start,
    EXTRACT(EPOCH FROM (NOW() - query_start)) as duration_seconds
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < NOW() - INTERVAL '5 seconds'
  AND usename IS NOT NULL
ORDER BY query_start;

-- Transaction timeout helper
CREATE OR REPLACE FUNCTION set_transaction_timeout(
    p_timeout_ms INT DEFAULT 30000
) RETURNS VOID AS $$
BEGIN
    SET LOCAL statement_timeout = p_timeout_ms || 'ms';
END;
$$ LANGUAGE plpgsql;

-- Kill long-running query (for admin)
CREATE OR REPLACE FUNCTION admin_kill_query(p_pid BIGINT) RETURNS BOOLEAN AS $$
BEGIN
    IF current_setting('surypus.admin_mode', true) = 'true' THEN
        PERFORM pg_terminate_backend(p_pid);
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;