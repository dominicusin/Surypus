-- ============================================================
-- Backup Tables - Резервное копирование
-- ============================================================

-- Backups (резервные копии)
CREATE TABLE IF NOT EXISTS backup (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    btype SMALLINT NOT NULL,  -- 0=FULL, 1=INCREMENTAL, 2=DIFFERENTIAL, 3=DATABASE, 4=CONFIG
    status SMALLINT DEFAULT 0,  -- 0=PENDING, 1=RUNNING, 2=COMPLETED, 3=FAILED, 4=VERIFIED, 5=DELETED
    file_path VARCHAR(512) NOT NULL,
    file_size BIGINT DEFAULT 0,
    file_hash VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    flags INTEGER DEFAULT 0
);

-- Backup schedule (расписание)
CREATE TABLE IF NOT EXISTS backup_schedule (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    btype SMALLINT NOT NULL,
    schedule_expr VARCHAR(64) NOT NULL,  -- Cron expression
    retention_days INT DEFAULT 30,
    enabled BOOLEAN DEFAULT TRUE,
    last_run TIMESTAMPTZ,
    next_run TIMESTAMPTZ,
    flags INTEGER DEFAULT 0
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_backup_code ON backup(code);
CREATE INDEX IF NOT EXISTS idx_backup_status ON backup(status);
CREATE INDEX IF NOT EXISTS idx_backup_dates ON backup(created_at);

-- ============================================================
-- Функции
-- ============================================================

-- Создать задачу резервного копирования
CREATE OR REPLACE FUNCTION create_backup_task(
    p_code VARCHAR,
    p_name VARCHAR,
    p_btype SMALLINT,
    p_file_path VARCHAR
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO backup (code, name, btype, file_path, status)
    VALUES (p_code, p_name, p_btype, p_file_path, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Завершить резервное копирование
CREATE OR REPLACE FUNCTION complete_backup_task(
    p_backup_id BIGINT,
    p_file_size BIGINT,
    p_file_hash VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE backup 
    SET status = 2, file_size = p_file_size, file_hash = p_file_hash, completed_at = NOW()
    WHERE id = p_backup_id AND status = 1;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Записать ошибку
CREATE OR REPLACE FUNCTION fail_backup_task(p_backup_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE backup SET status = 3, completed_at = NOW() WHERE id = p_backup_id AND status = 1;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Проверить резервную копию
CREATE OR REPLACE FUNCTION verify_backup_task(p_backup_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE backup SET status = 4 WHERE id = p_backup_id AND status = 2;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- История резервных копий
CREATE VIEW v_backup_history AS
SELECT 
    b.id, b.code, b.name, b.btype, b.status, b.file_size, b.file_hash,
    b.created_at, b.completed_at,
    EXTRACT(EPOCH FROM (b.completed_at - b.created_at)) AS duration_seconds,
    CASE b.btype
        WHEN 0 THEN 'Полная'
        WHEN 1 THEN 'Инкрементная'
        WHEN 2 THEN 'Дифференциальная'
        WHEN 3 THEN 'База данных'
        WHEN 4 THEN 'Конфигурация'
    END AS type_name,
    CASE b.status
        WHEN 0 THEN 'Ожидает'
        WHEN 1 THEN 'Выполняется'
        WHEN 2 THEN 'Завершена'
        WHEN 3 THEN 'Ошибка'
        WHEN 4 THEN 'Проверена'
        WHEN 5 THEN 'Удалена'
    END AS status_name
FROM backup b
ORDER BY b.created_at DESC;

-- Последние резервные копии
CREATE VIEW v_latest_backups AS
SELECT DISTINCT ON (btype)
    b.id, b.code, b.name, b.btype, b.status, b.file_size, b.created_at
FROM backup b
WHERE b.status = 2
ORDER BY btype, b.created_at DESC;
