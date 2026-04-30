-- ============================================================================
-- SCHEMA: Job Server (Планировщик задач)
-- Соответствует C++ классам PPJobServer в ppserver.cpp и PPJob в ppjob.cpp
-- ============================================================================

-- Таблица заданий
CREATE TABLE IF NOT EXISTS job (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    job_type        VARCHAR(50) NOT NULL,   -- IMPORT, EXPORT, SYNC, REPORT, BACKUP, MAINTENANCE, NOTIFICATION, CALCULATION
    priority        INTEGER DEFAULT 50,     -- 0-100
    status          VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, RUNNING, COMPLETED, FAILED, CANCELLED, PAUSED
    scheduled_at    TIMESTAMP NOT NULL,
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    result          VARCHAR(20),            -- SUCCESS, WARNING, ERROR, TIMEOUT
    error_message   TEXT,
    progress        INTEGER DEFAULT 0,      -- 0-100
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT job_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT job_priority_check CHECK (priority >= 0 AND priority <= 100),
    CONSTRAINT job_status_check CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED', 'PAUSED')),
    CONSTRAINT job_progress_check CHECK (progress >= 0 AND progress <= 100)
);

-- Таблица параметров заданий
CREATE TABLE IF NOT EXISTS job_param (
    id              SERIAL PRIMARY KEY,
    job_id          INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
    param_key       VARCHAR(100) NOT NULL,
    param_value     TEXT,
    
    CONSTRAINT jp_job_key_unique UNIQUE (job_id, param_key)
);

-- Таблица истории выполнения
CREATE TABLE IF NOT EXISTS job_history (
    id              SERIAL PRIMARY KEY,
    job_id          INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20) NOT NULL,
    message         TEXT,
    progress        INTEGER DEFAULT 0,
    
    CONSTRAINT jh_job_fk FOREIGN KEY (job_id) REFERENCES job(id),
    CONSTRAINT jh_status_check CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED', 'PAUSED')),
    CONSTRAINT jh_progress_check CHECK (progress >= 0 AND progress <= 100)
);

-- Таблица триггеров заданий
CREATE TABLE IF NOT EXISTS job_trigger (
    id              SERIAL PRIMARY KEY,
    job_id          INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
    trigger_type    VARCHAR(50) NOT NULL,   -- MANUAL, SCHEDULED, EVENT, DEPENDENCY
    cron_expression VARCHAR(100),
    event_type      VARCHAR(100),
    parent_job_id   INTEGER REFERENCES job(id),
    enabled         BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT jt_job_type_unique UNIQUE (job_id, trigger_type)
);

-- Таблица ресурсов заданий
CREATE TABLE IF NOT EXISTS job_resource (
    id              SERIAL PRIMARY KEY,
    job_id          INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
    resource_type   VARCHAR(50) NOT NULL,   -- CPU, MEMORY, DISK, NETWORK
    limit_value     DECIMAL(10,2),
    used_value      DECIMAL(10,2),
    
    CONSTRAINT jr_job_fk FOREIGN KEY (job_id) REFERENCES job(id),
    CONSTRAINT jr_type_check CHECK (resource_type IN ('CPU', 'MEMORY', 'DISK', 'NETWORK'))
);

-- Таблица зависимостей заданий
CREATE TABLE IF NOT EXISTS job_dependency (
    id              SERIAL PRIMARY KEY,
    job_id          INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
    depends_on_id   INTEGER NOT NULL REFERENCES job(id),
    dependency_type VARCHAR(20) DEFAULT 'BLOCKS',  -- BLOCKS, WAITS_FOR
    
    CONSTRAINT jd_job_dependency_unique UNIQUE (job_id, depends_on_id),
    CONSTRAINT jd_no_self_reference CHECK (job_id != depends_on_id)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_job_status ON job(status);
CREATE INDEX IF NOT EXISTS idx_job_priority ON job(priority DESC);
CREATE INDEX IF NOT EXISTS idx_job_scheduled ON job(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_job_type ON job(job_type);
CREATE INDEX IF NOT EXISTS idx_jp_job ON job_param(job_id);
CREATE INDEX IF NOT EXISTS idx_jh_job ON job_history(job_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_jt_job ON job_trigger(job_id);
CREATE INDEX IF NOT EXISTS idx_jd_depends ON job_dependency(depends_on_id);

-- Функция: Рассчитать время ожидания
CREATE OR REPLACE FUNCTION calculate_wait_time(p_job_id INTEGER, p_current_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP)
RETURNS INTEGER AS $$
DECLARE
    v_scheduled_at TIMESTAMP;
    v_wait_seconds INTEGER;
BEGIN
    SELECT scheduled_at INTO v_scheduled_at
    FROM job
    WHERE id = p_job_id;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    v_wait_seconds := EXTRACT(EPOCH FROM (p_current_time - v_scheduled_at))::INTEGER;
    RETURN GREATEST(v_wait_seconds, 0);
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать длительность выполнения
CREATE OR REPLACE FUNCTION calculate_job_duration(p_job_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_started_at TIMESTAMP;
    v_completed_at TIMESTAMP;
    v_duration_seconds INTEGER;
BEGIN
    SELECT started_at, completed_at
    INTO v_started_at, v_completed_at
    FROM job
    WHERE id = p_job_id;
    
    IF NOT FOUND OR v_started_at IS NULL OR v_completed_at IS NULL THEN
        RETURN NULL;
    END IF;
    
    v_duration_seconds := EXTRACT(EPOCH FROM (v_completed_at - v_started_at))::INTEGER;
    RETURN v_duration_seconds;
END;
$$ LANGUAGE plpgsql;

-- Функция: Проверить просроченность задания
CREATE OR REPLACE FUNCTION is_job_overdue(p_job_id INTEGER, p_current_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
    v_status VARCHAR(20);
    v_scheduled_at TIMESTAMP;
BEGIN
    SELECT status, scheduled_at
    INTO v_status, v_scheduled_at
    FROM job
    WHERE id = p_job_id;
    
    RETURN v_status = 'PENDING' AND p_current_time > v_scheduled_at;
END;
$$ LANGUAGE plpgsql;

-- Функция: Получить следующее задание по приоритету
CREATE OR REPLACE FUNCTION get_next_job(p_limit INTEGER DEFAULT 1)
RETURNS TABLE (job_id INTEGER, name VARCHAR, job_type VARCHAR, priority INTEGER, scheduled_at TIMESTAMP) AS $$
BEGIN
    RETURN QUERY
    SELECT j.id, j.name, j.job_type, j.priority, j.scheduled_at
    FROM job j
    WHERE j.status = 'PENDING'
      AND j.scheduled_at <= CURRENT_TIMESTAMP
      AND NOT EXISTS (
        SELECT 1 FROM job_dependency jd
        WHERE jd.job_id = j.id
          AND jd.dependency_type = 'BLOCKS'
      )
      AND NOT EXISTS (
        SELECT 1 FROM job j2
        JOIN job_dependency jd2 ON jd2.depends_on_id = j2.id
        WHERE jd2.job_id = j.id
          AND j2.status NOT IN ('COMPLETED', 'CANCELLED', 'FAILED')
      )
    ORDER BY j.priority DESC, j.scheduled_at ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Процедура: Создать задание
CREATE OR REPLACE PROCEDURE create_job(
    p_name VARCHAR,
    p_job_type VARCHAR,
    p_priority INTEGER DEFAULT 50,
    p_scheduled_at TIMESTAMP,
    p_job_id OUT INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO job (name, job_type, priority, status, scheduled_at)
    VALUES (p_name, p_job_type, p_priority, 'PENDING', p_scheduled_at)
    RETURNING id INTO p_job_id;
    
    -- Записать в историю
    INSERT INTO job_history (job_id, status, message, progress)
    VALUES (p_job_id, 'PENDING', 'Job created', 0);
    
    RAISE NOTICE 'Job % created', p_job_id;
END;
$$;

-- Процедура: Запустить задание
CREATE OR REPLACE PROCEDURE start_job(p_job_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE job
    SET status = 'RUNNING',
        started_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_job_id;
    
    INSERT INTO job_history (job_id, status, message, progress)
    VALUES (p_job_id, 'RUNNING', 'Job started', 0);
    
    RAISE NOTICE 'Job % started', p_job_id;
END;
$$;

-- Процедура: Завершить задание
CREATE OR REPLACE PROCEDURE complete_job(
    p_job_id INTEGER,
    p_result VARCHAR,
    p_progress INTEGER DEFAULT 100,
    p_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE job
    SET status = 'COMPLETED',
        result = p_result,
        completed_at = CURRENT_TIMESTAMP,
        progress = p_progress,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_job_id;
    
    INSERT INTO job_history (job_id, status, message, progress)
    VALUES (p_job_id, 'COMPLETED', COALESCE(p_message, 'Job completed'), p_progress);
    
    RAISE NOTICE 'Job % completed with result %', p_job_id, p_result;
END;
$$;

-- Процедура: Отметить ошибку задания
CREATE OR REPLACE PROCEDURE fail_job(
    p_job_id INTEGER,
    p_error_message TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE job
    SET status = 'FAILED',
        result = 'ERROR',
        error_message = p_error_message,
        completed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_job_id;
    
    INSERT INTO job_history (job_id, status, message, progress)
    VALUES (p_job_id, 'FAILED', p_error_message, 0);
    
    RAISE NOTICE 'Job % failed: %', p_job_id, p_error_message;
END;
$$;

-- Процедура: Обновить прогресс
CREATE OR REPLACE PROCEDURE update_job_progress(
    p_job_id INTEGER,
    p_progress INTEGER,
    p_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE job
    SET progress = p_progress,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_job_id;
    
    INSERT INTO job_history (job_id, status, message, progress)
    VALUES (p_job_id, 'RUNNING', COALESCE(p_message, 'Progress updated'), p_progress);
END;
$$;

-- Процедура: Отменить задание
CREATE OR REPLACE PROCEDURE cancel_job(p_job_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE job
    SET status = 'CANCELLED',
        completed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_job_id
      AND status IN ('PENDING', 'RUNNING', 'PAUSED');
    
    INSERT INTO job_history (job_id, status, message, progress)
    VALUES (p_job_id, 'CANCELLED', 'Job cancelled', 0);
    
    RAISE NOTICE 'Job % cancelled', p_job_id;
END;
$$;

-- Процедура: Запустить следующее задание из очереди
CREATE OR REPLACE PROCEDURE process_next_job()
LANGUAGE plpgsql
AS $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Получить следующее задание
    SELECT job_id INTO v_job_id
    FROM get_next_job(1)
    LIMIT 1;
    
    IF v_job_id IS NOT NULL THEN
        CALL start_job(v_job_id);
        RAISE NOTICE 'Started job %', v_job_id;
    ELSE
        RAISE NOTICE 'No pending jobs';
    END IF;
END;
$$;

-- Представление: Активные задания
CREATE OR REPLACE VIEW v_active_jobs AS
SELECT 
    j.id,
    j.name,
    j.job_type,
    j.priority,
    j.status,
    j.progress,
    j.scheduled_at,
    j.started_at,
    calculate_wait_time(j.id) AS wait_time_seconds,
    calculate_job_duration(j.id) AS duration_seconds
FROM job j
WHERE j.status IN ('PENDING', 'RUNNING', 'PAUSED')
ORDER BY j.priority DESC, j.scheduled_at ASC;

-- Представление: Завершённые задания
CREATE OR REPLACE VIEW v_completed_jobs AS
SELECT 
    j.id,
    j.name,
    j.job_type,
    j.status,
    j.result,
    j.started_at,
    j.completed_at,
    calculate_job_duration(j.id) AS duration_seconds,
    j.progress
FROM job j
WHERE j.status IN ('COMPLETED', 'FAILED', 'CANCELLED')
ORDER BY j.completed_at DESC
LIMIT 100;

-- Представление: Просроченные задания
CREATE OR REPLACE VIEW v_overdue_jobs AS
SELECT 
    j.id,
    j.name,
    j.job_type,
    j.scheduled_at,
    CURRENT_TIMESTAMP AS current_time,
    calculate_wait_time(j.id) AS overdue_seconds
FROM job j
WHERE is_job_overdue(j.id) = TRUE
ORDER BY j.scheduled_at ASC;

-- Представление: Статистика заданий
CREATE OR REPLACE VIEW v_job_statistics AS
SELECT 
    job_type,
    status,
    COUNT(*) AS count,
    AVG(calculate_job_duration(id)) FILTER (WHERE completed_at IS NOT NULL)) AS avg_duration,
    MIN(scheduled_at) AS earliest_scheduled,
    MAX(scheduled_at) AS latest_scheduled
FROM job
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY job_type, status;

-- Представление: Очередь заданий с зависимостями
CREATE OR REPLACE VIEW v_job_queue AS
SELECT 
    j.id,
    j.name,
    j.job_type,
    j.priority,
    j.status,
    j.scheduled_at,
    COUNT(jd.id) AS dependency_count,
    CASE 
        WHEN COUNT(jd.id) > 0 THEN ARRAY_AGG(jd.depends_on_id)
        ELSE ARRAY[]::INTEGER[]
    END AS depends_on
FROM job j
LEFT JOIN job_dependency jd ON jd.job_id = j.id
WHERE j.status = 'PENDING'
GROUP BY j.id, j.name, j.job_type, j.priority, j.status, j.scheduled_at
ORDER BY j.priority DESC, j.scheduled_at ASC;

-- Триггер: Обновить updated_at
CREATE OR REPLACE FUNCTION update_job_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_job_updated
    BEFORE UPDATE ON job
    FOR EACH ROW
    EXECUTE FUNCTION update_job_timestamp();
