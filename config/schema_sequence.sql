-- ============================================================
-- Sequence Tables - Нумераторы
-- ============================================================

-- Sequences (нумераторы)
CREATE TABLE IF NOT EXISTS sequence (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(128) NOT NULL,
    template VARCHAR(64) NOT NULL,  -- Шаблон: {YYYY}/{NNN}
    prefix VARCHAR(32) DEFAULT '',
    last_number INT DEFAULT 0,
    next_number INT DEFAULT 1,
    period SMALLINT DEFAULT 4,  -- 0=DAILY, 1=MONTHLY, 2=QUARTERLY, 3=YEARLY, 4=UNLIMITED
    start_date DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Generated numbers history (история номеров)
CREATE TABLE IF NOT EXISTS sequence_number (
    id BIGSERIAL PRIMARY KEY,
    sequence_id BIGINT NOT NULL REFERENCES sequence(id),
    number VARCHAR(64) NOT NULL,
    value INT NOT NULL,
    dt DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(sequence_id, value)
);

-- Индексы для нумераторов
CREATE INDEX IF NOT EXISTS idx_sequence_code ON sequence(code);
CREATE INDEX IF NOT EXISTS idx_sequence_number_seq ON sequence_number(sequence_id);
CREATE INDEX IF NOT EXISTS idx_sequence_number_value ON sequence_number(value);

-- ============================================================
-- Функции для нумераторов
-- ============================================================

-- Получить следующий номер
CREATE OR REPLACE FUNCTION get_next_number(p_sequence_code VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    v_seq RECORD;
    v_number VARCHAR(64);
    v_template VARCHAR(64);
    v_zeros INT;
BEGIN
    -- Получить нумератор
    SELECT * INTO v_seq FROM sequence WHERE code = p_sequence_code FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sequence not found: %', p_sequence_code;
    END IF;
    
    -- Форматировать номер
    v_template := v_seq.template;
    v_zeros := length(replace(v_template, 'N', ''));
    
    v_number := v_seq.prefix || '/' || 
                lpad(v_seq.next_number::TEXT, v_zeros, '0');
    
    -- Обновить счётчик
    UPDATE sequence 
    SET last_number = next_number, next_number = next_number + 1 
    WHERE id = v_seq.id;
    
    -- Записать в историю
    INSERT INTO sequence_number (sequence_id, number, value, dt)
    VALUES (v_seq.id, v_number, v_seq.next_number, COALESCE(v_seq.start_date, CURRENT_DATE));
    
    RETURN v_number;
END;
$$ LANGUAGE plpgsql;

-- Получить текущий номер
CREATE OR REPLACE FUNCTION get_current_number(p_sequence_code VARCHAR)
RETURNS INT AS $$
DECLARE
    v_next INT;
BEGIN
    SELECT next_number INTO v_next FROM sequence WHERE code = p_sequence_code;
    RETURN COALESCE(v_next, 0);
END;
$$ LANGUAGE plpgsql;

-- Сбросить нумератор
CREATE OR REPLACE FUNCTION reset_sequence(p_sequence_code VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE sequence SET last_number = 0, next_number = 1 WHERE code = p_sequence_code;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Установить текущий номер
CREATE OR REPLACE FUNCTION set_sequence_number(
    p_sequence_code VARCHAR,
    p_number INT
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE sequence SET last_number = p_number, next_number = p_number + 1 
    WHERE code = p_sequence_code;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Создать нумератор
CREATE OR REPLACE FUNCTION create_sequence(
    p_code VARCHAR,
    p_name VARCHAR,
    p_template VARCHAR,
    p_prefix VARCHAR,
    p_period SMALLINT,
    p_start_date DATE
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO sequence (code, name, template, prefix, period, start_date)
    VALUES (p_code, p_name, p_template, p_prefix, p_period, p_start_date)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Все нумераторы
CREATE OR REPLACE VIEW v_sequences AS
SELECT 
    s.id, s.code, s.name, s.template, s.prefix,
    s.last_number, s.next_number, s.period, s.start_date,
    CASE s.period
        WHEN 0 THEN 'Ежедневный'
        WHEN 1 THEN 'Ежемесячный'
        WHEN 2 THEN 'Ежеквартальный'
        WHEN 3 THEN 'Ежегодный'
        ELSE 'Без ограничения'
    END AS period_name
FROM sequence s
ORDER BY s.name;

-- История номеров
CREATE OR REPLACE VIEW v_sequence_history AS
SELECT 
    sn.id, sn.sequence_id, s.code AS sequence_code,
    sn.number, sn.value, sn.dt, sn.created_at
FROM sequence_number sn
JOIN sequence s ON s.id = sn.sequence_id
ORDER BY sn.dt DESC, sn.value DESC;

-- Последние номера
CREATE OR REPLACE VIEW v_last_numbers AS
SELECT 
    s.code, s.name, s.last_number, s.next_number,
    sn.number AS last_generated, sn.dt AS last_date
FROM sequence s
LEFT JOIN LATERAL (
    SELECT number, value, dt 
    FROM sequence_number 
    WHERE sequence_id = s.id 
    ORDER BY value DESC 
    LIMIT 1
) sn ON true
ORDER BY s.code;
