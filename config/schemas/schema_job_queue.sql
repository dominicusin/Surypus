-- ============================================================
-- JobQueue Tables - Очередь заданий
-- ============================================================

CREATE TABLE IF NOT EXISTS job (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(128) NOT NULL,
    jtype SMALLINT NOT NULL,  -- 0=IMPORT, 1=EXPORT, 2=REPORT, 3=SYNC, 4=BACKUP
    status SMALLINT DEFAULT 0,  -- 0=PENDING, 1=RUNNING, 2=COMPLETED, 3=FAILED, 4=CANCELLED
    priority SMALLINT DEFAULT 5,
    job_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    UNIQUE(code)
);

CREATE INDEX IF NOT EXISTS idx_job_status ON job(status);
CREATE INDEX IF NOT EXISTS idx_job_priority ON job(priority DESC);
