-- ============================================================
-- Import/Export Tables - Импорт/Экспорт данных
-- ============================================================

-- Import/Export tasks (задачи импорта/экспорта)
CREATE TABLE IF NOT EXISTS import_export_task (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    ietype SMALLINT NOT NULL,  -- 0=IMPORT, 1=EXPORT
    format SMALLINT NOT NULL,  -- 0=CSV, 1=XLSX, 2=XML, 3=JSON, 4=DBF, 5=TXT, 6=HTML
    encoding SMALLINT DEFAULT 0,  -- 0=UTF8, 1=WINDOWS1251, 2=KOI8R, 3=ASCII
    file_path VARCHAR(512) NOT NULL,
    status SMALLINT DEFAULT 0,  -- 0=PENDING, 1=RUNNING, 2=COMPLETED, 3=FAILED, 4=CANCELLED
    total_records INT DEFAULT 0,
    processed INT DEFAULT 0,
    errors INT DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_by BIGINT REFERENCES person(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Import field mappings (маппинг полей)
CREATE TABLE IF NOT EXISTS import_field (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES import_export_task(id),
    field_name VARCHAR(64) NOT NULL,
    field_type SMALLINT NOT NULL,  -- 0=STRING, 1=NUMBER, 2=DATE, 3=BOOLEAN, 4=DECIMAL
    required BOOLEAN DEFAULT FALSE,
    default_value VARCHAR(256),
    mapping VARCHAR(128),  -- Маппинг на поле БД
    position INT  -- Позиция в файле
);

-- Import/Export errors (ошибки)
CREATE TABLE IF NOT EXISTS import_export_error (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES import_export_task(id),
    line_number INT,
    field_name VARCHAR(64),
    error_message TEXT NOT NULL,
    original_data TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_import_export_task_code ON import_export_task(code);
CREATE INDEX IF NOT EXISTS idx_import_export_task_status ON import_export_task(status);
CREATE INDEX IF NOT EXISTS idx_import_export_task_dates ON import_export_task(created_at);

CREATE INDEX IF NOT EXISTS idx_import_field_task ON import_field(task_id);

CREATE INDEX IF NOT EXISTS idx_import_export_error_task ON import_export_error(task_id);

-- ============================================================
-- Функции
-- ============================================================

-- Создать задачу импорта
CREATE OR REPLACE FUNCTION create_import_task(
    p_code VARCHAR,
    p_name VARCHAR,
    p_format SMALLINT,
    p_encoding SMALLINT,
    p_file_path VARCHAR,
    p_created_by BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO import_export_task (code, name, ietype, format, encoding, file_path, created_by, status)
    VALUES (p_code, p_name, 0, p_format, p_encoding, p_file_path, p_created_by, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Создать задачу экспорта
CREATE OR REPLACE FUNCTION create_export_task(
    p_code VARCHAR,
    p_name VARCHAR,
    p_format SMALLINT,
    p_encoding SMALLINT,
    p_file_path VARCHAR,
    p_created_by BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO import_export_task (code, name, ietype, format, encoding, file_path, created_by, status)
    VALUES (p_code, p_name, 1, p_format, p_encoding, p_file_path, p_created_by, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Начать выполнение
CREATE OR REPLACE FUNCTION start_import_export(p_task_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE import_export_task SET status = 1, started_at = NOW() WHERE id = p_task_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Завершить выполнение
CREATE OR REPLACE FUNCTION complete_import_export(
    p_task_id BIGINT,
    p_total_records INT,
    p_processed INT,
    p_errors INT
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE import_export_task 
    SET status = 2, total_records = p_total_records, processed = p_processed, 
        errors = p_errors, completed_at = NOW()
    WHERE id = p_task_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Записать ошибку
CREATE OR REPLACE FUNCTION record_import_error(
    p_task_id BIGINT,
    p_line_number INT,
    p_field_name VARCHAR,
    p_error_message TEXT,
    p_original_data TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO import_export_error (task_id, line_number, field_name, error_message, original_data)
    VALUES (p_task_id, p_line_number, p_field_name, p_error_message, p_original_data)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- История импорта/экспорта
CREATE OR REPLACE VIEW v_import_export_history AS
SELECT 
    ie.id, ie.code, ie.name, ie.ietype, ie.format, ie.status,
    ie.total_records, ie.processed, ie.errors,
    ie.started_at, ie.completed_at, ie.created_at,
    p.name AS created_by_name,
    CASE ie.ietype WHEN 0 THEN 'Импорт' ELSE 'Экспорт' END AS type_name,
    CASE ie.format
        WHEN 0 THEN 'CSV'
        WHEN 1 THEN 'XLSX'
        WHEN 2 THEN 'XML'
        WHEN 3 THEN 'JSON'
        WHEN 4 THEN 'DBF'
        WHEN 5 THEN 'TXT'
        WHEN 6 THEN 'HTML'
    END AS format_name,
    CASE ie.status
        WHEN 0 THEN 'Ожидает'
        WHEN 1 THEN 'Выполняется'
        WHEN 2 THEN 'Завершён'
        WHEN 3 THEN 'Ошибка'
        WHEN 4 THEN 'Отменён'
    END AS status_name
FROM import_export_task ie
LEFT JOIN person p ON p.id = ie.created_by
ORDER BY ie.created_at DESC;

-- Ошибки импорта
CREATE TABLE IF NOT EXISTS v_import_errors AS
SELECT 
    ie.id, ie.task_id, ie.line_number, ie.field_name, ie.error_message,
    ie.original_data, ie.created_at,
    t.name AS task_name
FROM import_export_error ie
JOIN import_export_task t ON t.id = ie.task_id
ORDER BY ie.created_at DESC;
