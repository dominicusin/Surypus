-- ============================================================
-- Barcode Tables - Штрих-коды
-- ============================================================

-- Barcode types (типы штрих-кодов)
CREATE TABLE IF NOT EXISTS barcode_type (
    id SMALLSERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    code VARCHAR(16) NOT NULL,
    length_min INT DEFAULT 1,
    length_max INT DEFAULT 100,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Barcodes (штрих-коды)
CREATE TABLE IF NOT EXISTS barcode (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    btype SMALLINT NOT NULL REFERENCES barcode_type(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    quantity NUMERIC(18,6) DEFAULT 1,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Barcode scan history (история сканирований)
CREATE TABLE IF NOT EXISTS barcode_scan (
    id BIGSERIAL PRIMARY KEY,
    barcode_id BIGINT REFERENCES barcode(id),
    scan_time TIMESTAMPTZ DEFAULT NOW(),
    scanned_by BIGINT REFERENCES person(id),
    location_id BIGINT REFERENCES location(id),
    device_id BIGINT REFERENCES device(id),
    qtty NUMERIC(18,6),
    status SMALLINT DEFAULT 0  -- 0=SUCCESS, 1=NOT_FOUND, 2=INVALID
);

-- Индексы для штрих-кодов
CREATE INDEX IF NOT EXISTS idx_barcode_code ON barcode(code);
CREATE INDEX IF NOT EXISTS idx_barcode_goods ON barcode(goods_id);
CREATE INDEX IF NOT EXISTS idx_barcode_type ON barcode(btype);

CREATE INDEX IF NOT EXISTS idx_barcode_scan_time ON barcode_scan(scan_time);
CREATE INDEX IF NOT EXISTS idx_barcode_scan_barcode ON barcode_scan(barcode_id);

-- ============================================================
-- Функции для штрих-кодов
-- ============================================================

-- Валидация EAN-13
CREATE OR REPLACE FUNCTION validate_ean13(p_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_sum INT := 0;
    v_check INT;
    v_calc_check INT;
BEGIN
    IF length(p_code) != 13 THEN
        RETURN FALSE;
    END IF;
    
    -- Проверка что все символы - цифры
    IF p_code !~ '^[0-9]{13}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Вычисление контрольной суммы
    FOR i IN 1..12 LOOP
        IF i % 2 = 1 THEN
            v_sum := v_sum + substring(p_code from i for 1)::INT;
        ELSE
            v_sum := v_sum + 3 * substring(p_code from i for 1)::INT;
        END IF;
    END LOOP;
    
    v_check := substring(p_code from 13 for 1)::INT;
    v_calc_check := (10 - (v_sum % 10)) % 10;
    
    RETURN v_check = v_calc_check;
END;
$$ LANGUAGE plpgsql;

-- Валидация EAN-8
CREATE OR REPLACE FUNCTION validate_ean8(p_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_sum INT := 0;
    v_check INT;
    v_calc_check INT;
BEGIN
    IF length(p_code) != 8 THEN
        RETURN FALSE;
    END IF;
    
    IF p_code !~ '^[0-9]{8}$' THEN
        RETURN FALSE;
    END IF;
    
    FOR i IN 1..7 LOOP
        IF i % 2 = 1 THEN
            v_sum := v_sum + 3 * substring(p_code from i for 1)::INT;
        ELSE
            v_sum := v_sum + substring(p_code from i for 1)::INT;
        END IF;
    END LOOP;
    
    v_check := substring(p_code from 8 for 1)::INT;
    v_calc_check := (10 - (v_sum % 10)) % 10;
    
    RETURN v_check = v_calc_check;
END;
$$ LANGUAGE plpgsql;

-- Поиск товара по штрих-коду
CREATE OR REPLACE FUNCTION find_goods_by_barcode(p_code VARCHAR)
RETURNS BIGINT AS $$
DECLARE
    v_goods_id BIGINT;
BEGIN
    SELECT b.goods_id INTO v_goods_id
    FROM barcode b
    WHERE b.code = p_code
    LIMIT 1;
    
    RETURN v_goods_id;
END;
$$ LANGUAGE plpgsql;

-- Записать сканирование
CREATE OR REPLACE FUNCTION record_barcode_scan(
    p_barcode_id BIGINT,
    p_scanned_by BIGINT,
    p_location_id BIGINT,
    p_device_id BIGINT,
    p_qtty NUMERIC(18,6),
    p_status SMALLINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO barcode_scan (barcode_id, scanned_by, location_id, device_id, qtty, status)
    VALUES (p_barcode_id, p_scanned_by, p_location_id, p_device_id, p_qtty, p_status)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Все штрих-коды товаров
CREATE OR REPLACE VIEW v_goods_barcodes AS
SELECT 
    b.id, b.code, b.btype, bt.name AS type_name,
    b.goods_id, g.name AS goods_name,
    b.unit_id, u.name AS unit_name,
    b.quantity
FROM barcode b
JOIN barcode_type bt ON bt.id = b.btype
JOIN goods g ON g.id = b.goods_id
LEFT JOIN unit u ON u.id = b.unit_id
ORDER BY g.name, b.code;

-- История сканирований
CREATE OR REPLACE VIEW v_barcode_scan_history AS
SELECT 
    bs.id, bs.scan_time, bs.qtty, bs.status,
    b.code AS barcode_code,
    g.name AS goods_name,
    p.name AS scanned_by_name,
    l.name AS location_name,
    d.name AS device_name,
    CASE bs.status
        WHEN 0 THEN 'Успешно'
        WHEN 1 THEN 'Не найден'
        WHEN 2 THEN 'Невалиден'
    END AS status_name
FROM barcode_scan bs
LEFT JOIN barcode b ON b.id = bs.barcode_id
LEFT JOIN goods g ON g.id = b.goods_id
LEFT JOIN person p ON p.id = bs.scanned_by
LEFT JOIN location l ON l.id = bs.location_id
LEFT JOIN device d ON d.id = bs.device_id
ORDER BY bs.scan_time DESC;

-- Товары без штрих-кода
CREATE OR REPLACE VIEW v_goods_without_barcode AS
SELECT g.id, g.name, g.code
FROM goods g
WHERE NOT EXISTS (SELECT 1 FROM barcode b WHERE b.goods_id = g.id)
ORDER BY g.name;
