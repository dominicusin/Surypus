-- ============================================================
-- EGAIS Tables - ЕГАИС (алкогольный учёт)
-- Соответствует C++ egais.cpp
-- ============================================================

-- Egais marks (акцизные марки)
CREATE TABLE IF NOT EXISTS egais_mark (
    id BIGSERIAL PRIMARY KEY,
    barcode VARCHAR(68) NOT NULL,  -- PDF417 = 68 символов
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    lot_id BIGINT REFERENCES lot(id),
    status SMALLINT DEFAULT 0,  -- 0=AVAILABLE, 1=SOLD, 2=RETURNED, 3=INVALID, 4=DESTROYED
    scan_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(barcode)
);

-- Form A (справки А к партиям)
CREATE TABLE IF NOT EXISTS egais_form_a (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(20) NOT NULL,
    dt DATE NOT NULL,
    producer_inn VARCHAR(12) NOT NULL,
    producer_name VARCHAR(256) NOT NULL,
    product_id BIGINT NOT NULL REFERENCES goods(id),
    volume NUMERIC(18,4) NOT NULL,  -- в даллах
    strength NUMERIC(5,2) NOT NULL,  -- крепость
    excise NUMERIC(18,4) DEFAULT 0,  -- сумма акциза
    bill_id BIGINT REFERENCES bill(id),
    status SMALLINT DEFAULT 0,  -- 0=PENDING, 1=CONFIRMED, 2=REJECTED, 3=CANCELLED
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number)
);

-- Form B (справки Б к документам)
CREATE TABLE IF NOT EXISTS egais_form_b (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(20) NOT NULL,
    dt DATE NOT NULL,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    buyer_id BIGINT NOT NULL REFERENCES person(id),
    total_volume NUMERIC(18,4) DEFAULT 0,
    total_excise NUMERIC(18,4) DEFAULT 0,
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=SENT, 2=RECEIVED, 3=CANCELLED
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number, bill_id)
);

-- Egais transactions (транзакции с ЕГАИС)
CREATE TABLE IF NOT EXISTS egais_transaction (
    id BIGSERIAL PRIMARY KEY,
    tx_type SMALLINT NOT NULL,  -- 0=WAYBILL, 1=RETAIL, 2=RETURN, 3=TRANSFER, 4=REPORT
    doc_id VARCHAR(36) NOT NULL,  -- Исходящий ID
    reply_id VARCHAR(36),
    status SMALLINT DEFAULT 0,  -- 0=PENDING, 1=SENT, 2=ACCEPTED, 3=REJECTED, 4=ERROR
    dt DATE NOT NULL,
    content TEXT,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alcohol licenses (лицензии на алкоголь)
CREATE TABLE IF NOT EXISTS alcohol_license (
    id BIGSERIAL PRIMARY KEY,
    org_id BIGINT NOT NULL REFERENCES person(id),
    license_no VARCHAR(32) NOT NULL,
    dt_from DATE NOT NULL,
    dt_to DATE NOT NULL,
    license_type SMALLINT NOT NULL,  -- 0=PRODUCTION, 1=WHOLESALE, 2=RETAIL
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(license_no, org_id)
);

-- Индексы для EGAIS
CREATE INDEX IF NOT EXISTS idx_egais_mark_barcode ON egais_mark(barcode);
CREATE INDEX IF NOT EXISTS idx_egais_mark_goods ON egais_mark(goods_id);
CREATE INDEX IF NOT EXISTS idx_egais_mark_lot ON egais_mark(lot_id);
CREATE INDEX IF NOT EXISTS idx_egais_mark_status ON egais_mark(status);

CREATE INDEX IF NOT EXISTS idx_egais_form_a_number ON egais_form_a(number);
CREATE INDEX IF NOT EXISTS idx_egais_form_a_producer ON egais_form_a(producer_inn);
CREATE INDEX IF NOT EXISTS idx_egais_form_a_product ON egais_form_a(product_id);

CREATE INDEX IF NOT EXISTS idx_egais_form_b_bill ON egais_form_b(bill_id);
CREATE INDEX IF NOT EXISTS idx_egais_form_b_buyer ON egais_form_b(buyer_id);

CREATE INDEX IF NOT EXISTS idx_egais_transaction_doc ON egais_transaction(doc_id);
CREATE INDEX IF NOT EXISTS idx_egais_transaction_reply ON egais_transaction(reply_id);
CREATE INDEX IF NOT EXISTS idx_egais_transaction_status ON egais_transaction(status);

-- ============================================================
-- Функции для EGAIS
-- ============================================================

-- Расчёт акциза
CREATE OR REPLACE FUNCTION calc_excise(
    p_volume NUMERIC(18,4),
    p_strength NUMERIC(5,2),
    p_rate NUMERIC(18,4)
) RETURNS NUMERIC(18,4) AS $$
BEGIN
    RETURN p_volume * p_strength * p_rate;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Проверка марки (упрощённая)
CREATE OR REPLACE FUNCTION validate_egais_barcode(p_barcode VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    -- PDF417 должен быть 68 символов
    IF length(p_barcode) != 68 THEN
        RETURN FALSE;
    END IF;
    
    -- Дополнительная проверка может включать контрольную сумму
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Регистрация проданной марки
CREATE OR REPLACE FUNCTION register_mark_sold(p_barcode VARCHAR, p_sale_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE egais_mark 
    SET status = 1, scan_date = p_sale_date
    WHERE barcode = p_barcode AND status = 0;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Получить марки для партии
CREATE OR REPLACE FUNCTION get_marks_by_lot(p_lot_id BIGINT)
RETURNS TABLE (id BIGINT, barcode VARCHAR, status SMALLINT) AS $$
BEGIN
    RETURN QUERY
    SELECT em.id, em.barcode, em.status
    FROM egais_mark em
    WHERE em.lot_id = p_lot_id
    ORDER BY em.id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Остаток марок на складе
CREATE OR REPLACE VIEW v_egais_marks_available AS
SELECT 
    em.id, em.barcode, em.goods_id, g.name AS goods_name,
    em.lot_id, l.dt AS lot_date
FROM egais_mark em
JOIN goods g ON g.id = em.goods_id
LEFT JOIN lot l ON l.id = em.lot_id
WHERE em.status = 0  -- AVAILABLE
ORDER BY em.id;

-- Проданные марки за период
CREATE OR REPLACE VIEW v_egais_marks_sold AS
SELECT 
    em.id, em.barcode, em.goods_id, g.name AS goods_name,
    em.scan_date
FROM egais_mark em
JOIN goods g ON g.id = em.goods_id
WHERE em.status = 1  -- SOLD
    AND em.scan_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY em.scan_date DESC;

-- Справки А к подтверждению
CREATE TABLE IF NOT EXISTS v_egais_form_a_pending AS
SELECT 
    fa.id, fa.number, fa.dt, fa.producer_name,
    fa.product_id, g.name AS product_name,
    fa.volume, fa.strength, fa.excise
FROM egais_form_a fa
JOIN goods g ON g.id = fa.product_id
WHERE fa.status = 0  -- PENDING
ORDER BY fa.dt;

-- Просмотр транзакций EGAIS
CREATE OR REPLACE VIEW v_egais_transactions AS
SELECT 
    et.id, et.tx_type, et.doc_id, et.reply_id,
    et.status, et.dt, et.error,
    CASE et.tx_type 
        WHEN 0 THEN 'Товарная накладная'
        WHEN 1 THEN 'Розничная продажа'
        WHEN 2 THEN 'Возврат'
        WHEN 3 THEN 'Перемещение'
        WHEN 4 THEN 'Отчёт'
    END AS tx_type_name,
    CASE et.status
        WHEN 0 THEN 'Ожидает'
        WHEN 1 THEN 'Отправлена'
        WHEN 2 THEN 'Принята'
        WHEN 3 THEN 'Отклонена'
        WHEN 4 THEN 'Ошибка'
    END AS status_name
FROM egais_transaction et
ORDER BY et.dt DESC;

-- Просроченные лицензии
CREATE TABLE IF NOT EXISTS v_alcohol_licenses_expiring AS
SELECT 
    al.id, al.org_id, p.name AS org_name,
    al.license_no, al.dt_from, al.dt_to,
    al.dt_to - CURRENT_DATE AS days_until_expiry
FROM alcohol_license al
JOIN person p ON p.id = al.org_id
WHERE al.dt_to < CURRENT_DATE + INTERVAL '30 days'
    AND al.status = 0
ORDER BY al.dt_to;
