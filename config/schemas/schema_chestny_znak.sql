-- ============================================================================
-- SCHEMA: Chestny Znak (Честный знак - маркировка товаров)
-- Соответствует C++ классам PPChZnPrcssr в chkpan.cpp
-- ============================================================================

-- Таблица кодов маркировки
CREATE TABLE IF NOT EXISTS mark_code (
    id              SERIAL PRIMARY KEY,
    code            VARCHAR(90) NOT NULL,   -- Data Matrix 90 символов
    gtin            VARCHAR(14) NOT NULL,   -- GTIN-14
    serial          VARCHAR(50) NOT NULL,
    status          VARCHAR(20) DEFAULT 'ACTIVE',  -- ACTIVE, USED, RETIRED, INVALID, RETURNED
    goods_id        INTEGER NOT NULL,
    lot_id          INTEGER,
    pack_id         INTEGER,                -- ID упаковки
    scan_date       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mc_code_unique UNIQUE (code),
    CONSTRAINT mc_gtin_format CHECK (gtin ~ '^[0-9]{14}$'),
    CONSTRAINT mc_status_check CHECK (status IN ('ACTIVE', 'USED', 'RETIRED', 'INVALID', 'RETURNED'))
);

-- Таблица операций с маркировкой
CREATE TABLE IF NOT EXISTS chzn_operation (
    id              SERIAL PRIMARY KEY,
    operation_type  VARCHAR(30) NOT NULL,   -- AGGREGATION, DISAGGREGATION, RECEIPT, SHIPMENT, RETAIL, RETURN, WRITE_OFF
    mark_code_id    INTEGER REFERENCES mark_code(id),
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, SENT, ACCEPTED, REJECTED
    document_id     INTEGER,
    request_id      VARCHAR(50),            -- ID запроса в ЧЗ
    response_code   VARCHAR(20),
    response_message TEXT,
    
    CONSTRAINT czo_type_check CHECK (operation_type IN ('AGGREGATION', 'DISAGGREGATION', 'RECEIPT', 'SHIPMENT', 'RETAIL', 'RETURN', 'WRITE_OFF')),
    CONSTRAINT czo_status_check CHECK (status IN ('PENDING', 'SENT', 'ACCEPTED', 'REJECTED'))
);

-- Таблица упаковок (агрегация)
CREATE TABLE IF NOT EXISTS aggregation_unit (
    id              SERIAL PRIMARY KEY,
    unit_type       VARCHAR(20) NOT NULL,   -- INDIVIDUAL, GROUP, BOX, PALLET
    gtin            VARCHAR(14) NOT NULL,
    serial          VARCHAR(50) NOT NULL,
    child_count     INTEGER DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'ACTIVE',
    parent_id       INTEGER REFERENCES aggregation_unit(id),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT au_type_check CHECK (unit_type IN ('INDIVIDUAL', 'GROUP', 'BOX', 'PALLET')),
    CONSTRAINT au_status_check CHECK (status IN ('ACTIVE', 'USED', 'RETIRED', 'INVALID'))
);

-- Таблица агрегации (содержимое упаковок)
CREATE TABLE IF NOT EXISTS aggregation_content (
    id              SERIAL PRIMARY KEY,
    parent_id       INTEGER NOT NULL REFERENCES aggregation_unit(id) ON DELETE CASCADE,
    child_type      VARCHAR(20) NOT NULL,   -- MARK_CODE или AGGREGATION_UNIT
    child_id        INTEGER NOT NULL,
    
    CONSTRAINT ac_parent_child_unique UNIQUE (parent_id, child_type, child_id)
);

-- Таблица кодов ожидающих агрегации
CREATE TABLE IF NOT EXISTS mark_code_aggregation_queue (
    id              SERIAL PRIMARY KEY,
    mark_code_id    INTEGER NOT NULL REFERENCES mark_code(id),
    target_unit_id  INTEGER NOT NULL REFERENCES aggregation_unit(id),
    status          VARCHAR(20) DEFAULT 'PENDING',
    added_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mcaq_unique UNIQUE (mark_code_id, target_unit_id)
);

-- Таблица документов для Честного знака
CREATE TABLE IF NOT EXISTS chzn_document (
    id              SERIAL PRIMARY KEY,
    doc_type        VARCHAR(30) NOT NULL,   -- агрегация, упаковка, отгрузка, приемка и т.д.
    doc_number      VARCHAR(50),
    doc_date        DATE,
    sender_inn      VARCHAR(12),
    receiver_inn    VARCHAR(12),
    status          VARCHAR(20) DEFAULT 'DRAFT',
    request_id      VARCHAR(50),
    response_id     VARCHAR(50),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT cd_type_check CHECK (doc_type IN ('aggregation', 'disaggregation', 'shipment', 'receipt', 'retail', 'return', 'write_off'))
);

-- Таблица ошибок маркировки
CREATE TABLE IF NOT EXISTS mark_code_error (
    id              SERIAL PRIMARY KEY,
    mark_code_id    INTEGER REFERENCES mark_code(id),
    error_code      VARCHAR(20) NOT NULL,
    error_message   TEXT,
    operation_id    INTEGER REFERENCES chzn_operation(id),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mce_code_check CHECK (error_code IN ('INVALID_FORMAT', 'INVALID_GTIN', 'DUPLICATE', 'NOT_FOUND', 'WRONG_STATUS', 'EXPIRED'))
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_mc_code ON mark_code(code);
CREATE INDEX IF NOT EXISTS idx_mc_gtin ON mark_code(gtin);
CREATE INDEX IF NOT EXISTS idx_mc_status ON mark_code(status);
CREATE INDEX IF NOT EXISTS idx_mc_goods ON mark_code(goods_id);
CREATE INDEX IF NOT EXISTS idx_czo_mark_code ON chzn_operation(mark_code_id);
CREATE INDEX IF NOT EXISTS idx_czo_timestamp ON chzn_operation(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_au_parent ON aggregation_unit(parent_id);
CREATE INDEX IF NOT EXISTS idx_ac_parent ON aggregation_content(parent_id);

-- Функция: Проверить формат GTIN
CREATE OR REPLACE FUNCTION validate_gtin_format(p_gtin VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_gtin ~ '^[0-9]{14}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Проверить контрольную цифру GTIN
CREATE OR REPLACE FUNCTION validate_gtin_checkdigit(p_gtin VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_digits VARCHAR(13);
    v_check_digit INTEGER;
    v_sum INTEGER := 0;
    v_i INTEGER;
    v_calc_digit INTEGER;
BEGIN
    IF p_gtin !~ '^[0-9]{14}$' THEN
        RETURN FALSE;
    END IF;
    
    v_digits := SUBSTRING(p_gtin FROM 1 FOR 13);
    v_check_digit := SUBSTRING(p_gtin FROM 14 FOR 1)::INTEGER;
    
    FOR v_i IN 1..13 LOOP
        IF v_i % 2 = 0 THEN
            v_sum := v_sum + SUBSTRING(v_digits FROM v_i FOR 1)::INTEGER * 3;
        ELSE
            v_sum := v_sum + SUBSTRING(v_digits FROM v_i FOR 1)::INTEGER;
        END IF;
    END LOOP;
    
    v_calc_digit := (10 - (v_sum % 10)) % 10;
    
    RETURN v_calc_digit = v_check_digit;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Проверить формат Data Matrix кода
CREATE OR REPLACE FUNCTION validate_dm_code(p_code VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN LENGTH(p_code) = 90 AND p_code ~ '^[0-9A-Z]+$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Распарсить код маркировки
CREATE OR REPLACE FUNCTION parse_mark_code(p_code VARCHAR)
RETURNS TABLE (gtin VARCHAR, serial VARCHAR) AS $$
BEGIN
    IF LENGTH(p_code) < 14 THEN
        RETURN;
    END IF;
    
    -- GTIN первые 14 символов
    -- Серийный номер остальное
    RETURN QUERY
    SELECT 
        SUBSTRING(p_code FROM 1 FOR 14) AS gtin,
        SUBSTRING(p_code FROM 15 FOR LENGTH(p_code) - 14) AS serial;
END;
$$ LANGUAGE plpgsql;

-- Процедура: Добавить код маркировки
CREATE OR REPLACE PROCEDURE add_mark_code(
    p_code VARCHAR,
    p_goods_id INTEGER,
    p_lot_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_gtin VARCHAR(14);
    v_serial VARCHAR(50);
BEGIN
    -- Проверить формат
    IF NOT validate_dm_code(p_code) THEN
        RAISE EXCEPTION 'Invalid Data Matrix code format';
    END IF;
    
    -- Распарсить
    SELECT gtin, serial INTO v_gtin, v_serial
    FROM parse_mark_code(p_code);
    
    IF NOT validate_gtin_format(v_gtin) THEN
        RAISE EXCEPTION 'Invalid GTIN format';
    END IF;
    
    IF NOT validate_gtin_checkdigit(v_gtin) THEN
        RAISE EXCEPTION 'Invalid GTIN check digit';
    END IF;
    
    -- Добавить
    INSERT INTO mark_code (code, gtin, serial, status, goods_id, lot_id)
    VALUES (p_code, v_gtin, v_serial, 'ACTIVE', p_goods_id, p_lot_id)
    ON CONFLICT (code) DO NOTHING;
    
    RAISE NOTICE 'Mark code added: %', p_code;
END;
$$;

-- Процедура: Использовать код (продажа)
CREATE OR REPLACE PROCEDURE use_mark_code(p_code VARCHAR, p_document_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE mark_code
    SET status = 'USED'
    WHERE code = p_code AND status = 'ACTIVE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mark code not found or already used';
    END IF;
    
    -- Записать операцию
    INSERT INTO chzn_operation (operation_type, mark_code_id, status, document_id)
    SELECT 'RETAIL', id, 'ACCEPTED', p_document_id
    FROM mark_code
    WHERE code = p_code;
    
    RAISE NOTICE 'Mark code used: %', p_code;
END;
$$;

-- Процедура: Создать упаковку (агрегация)
CREATE OR REPLACE PROCEDURE create_aggregation_unit(
    p_unit_type VARCHAR,
    p_gtin VARCHAR,
    p_serial VARCHAR,
    p_parent_id INTEGER DEFAULT NULL,
    p_unit_id OUT INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO aggregation_unit (unit_type, gtin, serial, parent_id, status)
    VALUES (p_unit_type, p_gtin, p_serial, p_parent_id, 'ACTIVE')
    RETURNING id INTO p_unit_id;
    
    RAISE NOTICE 'Aggregation unit created: %', p_unit_id;
END;
$$;

-- Процедура: Добавить код в упаковку
CREATE OR REPLACE PROCEDURE add_to_aggregation(
    p_mark_code VARCHAR,
    p_unit_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mark_code_id INTEGER;
    v_parent_unit_id INTEGER;
BEGIN
    -- Найти код
    SELECT id INTO v_mark_code_id
    FROM mark_code
    WHERE code = p_mark_code;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mark code not found';
    END IF;
    
    -- Добавить в содержимое
    INSERT INTO aggregation_content (parent_id, child_type, child_id)
    VALUES (p_unit_id, 'MARK_CODE', v_mark_code_id);
    
    -- Обновить счётчик
    UPDATE aggregation_unit
    SET child_count = child_count + 1
    WHERE id = p_unit_id;
    
    -- Обновить статус кода
    UPDATE mark_code
    SET pack_id = p_unit_id, status = 'USED'
    WHERE id = v_mark_code_id;
    
    RAISE NOTICE 'Added mark code % to unit %', p_mark_code, p_unit_id;
END;
$$;

-- Процедура: Завершить упаковку
CREATE OR REPLACE PROCEDURE complete_aggregation(p_unit_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE aggregation_unit
    SET status = 'USED'
    WHERE id = p_unit_id;
    
    RAISE NOTICE 'Aggregation unit % completed', p_unit_id;
END;
$$;

-- Представление: Активные коды маркировки
CREATE OR REPLACE VIEW v_active_mark_codes AS
SELECT 
    mc.id,
    mc.code,
    mc.gtin,
    mc.serial,
    mc.status,
    g.name AS goods_name,
    mc.scan_date
FROM mark_code mc
LEFT JOIN goods g ON g.id = mc.goods_id
WHERE mc.status = 'ACTIVE'
ORDER BY mc.scan_date DESC;

-- Представление: Агрегированные упаковки
CREATE OR REPLACE VIEW v_aggregation_units AS
SELECT 
    au.id,
    au.unit_type,
    au.gtin,
    au.serial,
    au.child_count,
    au.status,
    parent.gtin AS parent_gtin,
    parent.serial AS parent_serial
FROM aggregation_unit au
LEFT JOIN aggregation_unit parent ON parent.id = au.parent_id
WHERE au.status = 'ACTIVE'
ORDER BY au.id;

-- Представление: Операции маркировки за период
CREATE OR REPLACE VIEW v_chzn_operations_period AS
SELECT 
    co.operation_type,
    co.timestamp,
    co.status,
    mc.gtin,
    mc.serial,
    co.response_message
FROM chzn_operation co
JOIN mark_code mc ON mc.id = co.mark_code_id
WHERE co.timestamp >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY co.timestamp DESC;

-- Представление: Ошибки маркировки
CREATE OR REPLACE VIEW v_mark_code_errors AS
SELECT 
    mce.error_code,
    mce.error_message,
    mc.gtin,
    mc.serial,
    mce.created_at
FROM mark_code_error mce
JOIN mark_code mc ON mc.id = mce.mark_code_id
ORDER BY mce.created_at DESC;

-- Представление: Статистика использования кодов
CREATE OR REPLACE VIEW v_mark_code_statistics AS
SELECT 
    mc.status,
    COUNT(*) AS count,
    COUNT(DISTINCT mc.goods_id) AS goods_count,
    MIN(mc.scan_date) AS earliest_scan,
    MAX(mc.scan_date) AS latest_scan
FROM mark_code mc
WHERE mc.scan_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY mc.status;
