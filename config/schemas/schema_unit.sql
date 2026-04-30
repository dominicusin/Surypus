-- ============================================================
-- Unit Tables - Единицы измерения
-- ============================================================

-- Unit groups (группы единиц)
CREATE TABLE IF NOT EXISTS unit_group (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    dimension SMALLINT NOT NULL,  -- 0=LENGTH, 1=MASS, 2=VOLUME, 3=AREA, 4=TIME, 5=COUNT, 6=MONEY
    UNIQUE(code)
);

-- Units (единицы измерения)
CREATE TABLE IF NOT EXISTS unit (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    group_id BIGINT REFERENCES unit_group(id),
    is_base BOOLEAN DEFAULT FALSE,
    ratio NUMERIC(18,6) NOT NULL DEFAULT 1,  -- Коэффициент к базовой единице
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_unit_code ON unit(code);
CREATE INDEX IF NOT EXISTS idx_unit_group ON unit(group_id);

-- ============================================================
-- Функции
-- ============================================================

-- Конвертировать единицы
CREATE OR REPLACE FUNCTION convert_units(
    p_amount NUMERIC(18,6),
    p_from_unit_id BIGINT,
    p_to_unit_id BIGINT
) RETURNS NUMERIC(18,6) AS $$
DECLARE
    v_from_ratio NUMERIC(18,6);
    v_to_ratio NUMERIC(18,6);
BEGIN
    SELECT u.ratio INTO v_from_ratio FROM unit u WHERE u.id = p_from_unit_id;
    SELECT u.ratio INTO v_to_ratio FROM unit u WHERE u.id = p_to_unit_id;
    
    IF v_from_ratio IS NULL OR v_to_ratio IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN p_amount * v_from_ratio / v_to_ratio;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- Единицы по группам
CREATE VIEW v_units_by_group AS
SELECT 
    u.id, u.code, u.name, ug.name AS group_name, u.is_base, u.ratio,
    CASE ug.dimension
        WHEN 0 THEN 'Длина'
        WHEN 1 THEN 'Масса'
        WHEN 2 THEN 'Объём'
        WHEN 3 THEN 'Площадь'
        WHEN 4 THEN 'Время'
        WHEN 5 THEN 'Количество'
        WHEN 6 THEN 'Деньги'
    END AS dimension_name
FROM unit u
LEFT JOIN unit_group ug ON ug.id = u.group_id
ORDER BY ug.name, u.is_base DESC, u.name;
