-- ============================================================
-- Settings Tables - Настройки системы
-- ============================================================

-- Settings (настройки)
CREATE TABLE IF NOT EXISTS setting (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    sgroup VARCHAR(64) NOT NULL,
    value TEXT NOT NULL,
    stype SMALLINT NOT NULL,  -- 0=STRING, 1=NUMBER, 2=BOOLEAN, 3=DATE, 4=ENUM, 5=PASSWORD, 6=JSON
    default_value TEXT,
    required BOOLEAN DEFAULT FALSE,
    flags INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Setting groups (группы настроек)
CREATE TABLE IF NOT EXISTS setting_group (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_setting_code ON setting(code);
CREATE INDEX IF NOT EXISTS idx_setting_group ON setting(sgroup);

-- ============================================================
-- Функции
-- ============================================================

-- Получить настройку
CREATE OR REPLACE FUNCTION get_setting(p_code VARCHAR)
RETURNS TEXT AS $$
DECLARE
    v_value TEXT;
BEGIN
    SELECT s.value INTO v_value FROM setting s WHERE s.code = p_code;
    RETURN COALESCE(v_value, (SELECT default_value FROM setting WHERE code = p_code));
END;
$$ LANGUAGE plpgsql;

-- Установить настройку
CREATE OR REPLACE FUNCTION set_setting(p_code VARCHAR, p_value TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE setting SET value = p_value, updated_at = NOW() WHERE code = p_code;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Получить настройку как число
CREATE OR REPLACE FUNCTION get_setting_int(p_code VARCHAR, p_default INT)
RETURNS INT AS $$
BEGIN
    RETURN COALESCE(get_setting(p_code)::INT, p_default);
END;
$$ LANGUAGE plpgsql;

-- Получить настройку как булево
CREATE OR REPLACE FUNCTION get_setting_bool(p_code VARCHAR, p_default BOOLEAN)
RETURNS BOOLEAN AS $$
DECLARE
    v_value TEXT;
BEGIN
    v_value := get_setting(p_code);
    RETURN CASE WHEN v_value IS NULL THEN p_default 
                WHEN v_value IN ('true', '1', 'yes') THEN TRUE 
                ELSE FALSE 
           END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- Все настройки по группам
CREATE VIEW v_settings_by_group AS
SELECT 
    s.id, s.code, s.name, s.sgroup, s.value, s.stype, s.required, s.updated_at,
    CASE s.stype
        WHEN 0 THEN 'Строка'
        WHEN 1 THEN 'Число'
        WHEN 2 THEN 'Булево'
        WHEN 3 THEN 'Дата'
        WHEN 4 THEN 'Перечисление'
        WHEN 5 THEN 'Пароль'
        WHEN 6 THEN 'JSON'
    END AS type_name
FROM setting s
ORDER BY s.sgroup, s.name;

-- Обязательные настройки
CREATE VIEW v_required_settings AS
SELECT s.code, s.name, s.value, s.sgroup
FROM setting s
WHERE s.required = TRUE AND (s.value IS NULL OR s.value = '');
