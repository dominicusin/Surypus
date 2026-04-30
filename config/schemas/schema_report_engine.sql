-- ============================================================
-- Report Tables - Отчёты
-- ============================================================

-- Report definitions (определения отчётов)
CREATE TABLE IF NOT EXISTS report (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    rkind SMALLINT NOT NULL,  -- 0=FINANCIAL, 1=TRADE, 2=INVENTORY, 3=PRODUCTION, 4=HR, 5=TAX, 6=ANALYTICAL, 7=CUSTOM
    rtype SMALLINT NOT NULL,  -- 0=SUMMARY, 1=DETAILED, 2=DYNAMIC, 3=CROSS
    description TEXT,
    query_text TEXT,  -- SQL запрос
    template_path VARCHAR(512),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Report parameters (параметры отчётов)
CREATE TABLE IF NOT EXISTS report_param (
    id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES report(id),
    name VARCHAR(64) NOT NULL,
    ptype SMALLINT NOT NULL,  -- 0=STRING, 1=NUMBER, 2=DATE, 3=BOOLEAN, 4=LIST
    default_value VARCHAR(256),
    required BOOLEAN DEFAULT FALSE,
    flags INTEGER DEFAULT 0
);

-- Report instances (экземпляры отчётов)
CREATE TABLE IF NOT EXISTS report_instance (
    id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES report(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=GENERATING, 2=READY, 3=ERROR
    format SMALLINT DEFAULT 0,  -- 0=PDF, 1=XLSX, 2=HTML, 3=CSV, 4=JSON, 5=XML
    row_count INT DEFAULT 0,
    file_path VARCHAR(512),
    error_message TEXT,
    created_by BIGINT REFERENCES person(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Report parameters values (значения параметров)
CREATE TABLE IF NOT EXISTS report_param_value (
    id BIGSERIAL PRIMARY KEY,
    instance_id BIGINT NOT NULL REFERENCES report_instance(id),
    param_id BIGINT NOT NULL REFERENCES report_param(id),
    value VARCHAR(1024)
);

-- Индексы для отчётов
CREATE INDEX IF NOT EXISTS idx_report_code ON report(code);
CREATE INDEX IF NOT EXISTS idx_report_kind ON report(rkind);

CREATE INDEX IF NOT EXISTS idx_report_param_report ON report_param(report_id);

CREATE INDEX IF NOT EXISTS idx_report_instance_report ON report_instance(report_id);
CREATE INDEX IF NOT EXISTS idx_report_instance_status ON report_instance(status);
CREATE INDEX IF NOT EXISTS idx_report_instance_dates ON report_instance(period_start, period_end);

CREATE INDEX IF NOT EXISTS idx_report_param_value_instance ON report_param_value(instance_id);

-- ============================================================
-- Функции для отчётов
-- ============================================================

-- Создать экземпляр отчёта
CREATE OR REPLACE FUNCTION create_report_instance(
    p_report_id BIGINT,
    p_period_start DATE,
    p_period_end DATE,
    p_format SMALLINT,
    p_created_by BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO report_instance (report_id, period_start, period_end, format, status, created_by)
    VALUES (p_report_id, p_period_start, p_period_end, p_format, 0, p_created_by)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Начать генерацию
CREATE OR REPLACE FUNCTION start_report_generation(p_instance_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE report_instance SET status = 1 WHERE id = p_instance_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Завершить генерацию
CREATE OR REPLACE FUNCTION complete_report_generation(
    p_instance_id BIGINT,
    p_file_path VARCHAR,
    p_row_count INT
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE report_instance 
    SET status = 2, file_path = p_file_path, row_count = p_row_count, completed_at = NOW()
    WHERE id = p_instance_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Ошибка генерации
CREATE OR REPLACE FUNCTION report_generation_error(
    p_instance_id BIGINT,
    p_error_message TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE report_instance 
    SET status = 3, error_message = p_error_message, completed_at = NOW()
    WHERE id = p_instance_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Доступные отчёты
CREATE OR REPLACE VIEW v_reports AS
SELECT 
    r.id, r.code, r.name, r.rkind, r.rtype, r.description,
    COUNT(rp.id) AS param_count,
    CASE r.rkind
        WHEN 0 THEN 'Финансовый'
        WHEN 1 THEN 'Торговый'
        WHEN 2 THEN 'Складской'
        WHEN 3 THEN 'Производственный'
        WHEN 4 THEN 'Кадровый'
        WHEN 5 THEN 'Налоговый'
        WHEN 6 THEN 'Аналитический'
        ELSE 'Пользовательский'
    END AS kind_name,
    CASE r.rtype
        WHEN 0 THEN 'Сводный'
        WHEN 1 THEN 'Детализированный'
        WHEN 2 THEN 'Динамический'
        WHEN 3 THEN 'Кросс-таблица'
    END AS type_name
FROM report r
LEFT JOIN report_param rp ON rp.report_id = r.id
GROUP BY r.id, r.code, r.name, r.rkind, r.rtype, r.description
ORDER BY r.name;

-- История отчётов
CREATE OR REPLACE VIEW v_report_history AS
SELECT 
    ri.id, r.code AS report_code, r.name AS report_name,
    ri.period_start, ri.period_end,
    ri.status, ri.format, ri.row_count, ri.file_path,
    ri.created_at, ri.completed_at,
    p.name AS created_by_name,
    CASE ri.status
        WHEN 0 THEN 'Черновик'
        WHEN 1 THEN 'Генерируется'
        WHEN 2 THEN 'Готов'
        WHEN 3 THEN 'Ошибка'
    END AS status_name,
    CASE ri.format
        WHEN 0 THEN 'PDF'
        WHEN 1 THEN 'XLSX'
        WHEN 2 THEN 'HTML'
        WHEN 3 THEN 'CSV'
        WHEN 4 THEN 'JSON'
        WHEN 5 THEN 'XML'
    END AS format_name
FROM report_instance ri
JOIN report r ON r.id = ri.report_id
LEFT JOIN person p ON p.id = ri.created_by
ORDER BY ri.created_at DESC;

-- Готовые отчёты
CREATE OR REPLACE VIEW v_ready_reports AS
SELECT 
    ri.id, r.name AS report_name,
    ri.period_start, ri.period_end,
    ri.file_path, ri.row_count,
    ri.completed_at,
    EXTRACT(EPOCH FROM (ri.completed_at - ri.created_at)) AS generation_time
FROM report_instance ri
JOIN report r ON r.id = ri.report_id
WHERE ri.status = 2  -- READY
ORDER BY ri.completed_at DESC;
