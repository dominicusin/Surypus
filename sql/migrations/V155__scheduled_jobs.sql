-- Scheduled jobs table
CREATE TABLE IF NOT EXISTS scheduled_jobs (
    job_id BIGSERIAL PRIMARY KEY,
    job_name TEXT UNIQUE NOT NULL,
    function_name TEXT NOT NULL,
    schedule_interval INTERVAL NOT NULL,
    last_run TIMESTAMP WITH TIME ZONE,
    next_run TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Job execution log
CREATE TABLE IF NOT EXISTS job_execution_log (
    log_id BIGSERIAL PRIMARY KEY,
    job_id BIGINT REFERENCES scheduled_jobs(job_id),
    status TEXT CHECK (status IN ('running', 'success', 'failed')),
    message TEXT,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Register default jobs
INSERT INTO scheduled_jobs (job_name, function_name, schedule_interval, is_active)
VALUES 
    ('Cache Cleanup', 'cache_cleanup', INTERVAL '5 minutes', TRUE),
    ('Outbox Processing', 'outbox_cleanup', INTERVAL '1 minute', TRUE),
    ('Health Check', 'health_record', INTERVAL '5 minutes', TRUE),
    ('Materialized View Refresh', 'refresh_all_mv', INTERVAL '1 hour', TRUE)
ON CONFLICT (job_name) DO NOTHING;

-- Job runner
CREATE OR REPLACE FUNCTION run_scheduled_jobs() RETURNS VOID AS $$
DECLARE
    v_job RECORD;
    v_log_id BIGINT;
BEGIN
    FOR v_job IN 
        SELECT * FROM scheduled_jobs 
        WHERE is_active = TRUE 
          AND (next_run IS NULL OR next_run <= NOW())
    LOOP
        BEGIN
            INSERT INTO job_execution_log (job_id, status, started_at)
            VALUES (v_job.job_id, 'running', NOW())
            RETURNING log_id INTO v_log_id;
            
            EXECUTE format('SELECT %I()', v_job.function_name);
            
            UPDATE job_execution_log SET status = 'success', completed_at = NOW()
            WHERE log_id = v_log_id;
            
            UPDATE scheduled_jobs SET 
                last_run = NOW(),
                next_run = NOW() + v_job.schedule_interval
            WHERE job_id = v_job.job_id;
            
        EXCEPTION WHEN OTHERS THEN
            UPDATE job_execution_log SET status = 'failed', message = SQLERRM, completed_at = NOW()
            WHERE log_id = v_log_id;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;