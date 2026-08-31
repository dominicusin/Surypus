-- Lock monitoring view
CREATE OR REPLACE VIEW v_active_locks AS
SELECT
    l.locktype,
    l.relation::regclass as table_name,
    l.mode,
    l.granted,
    l.pid,
    a.usename as username,
    a.query
FROM pg_locks l
LEFT JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.relation IS NOT NULL
ORDER BY l.granted, l.pid;

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
    SET LOCAL statement_timeout = p_timeout_ms;
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