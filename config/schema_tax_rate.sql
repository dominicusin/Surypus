-- ============================================================
-- TaxRate Tables - Налоговые ставки
-- ============================================================

-- Tax types (типы налогов)
CREATE TABLE IF NOT EXISTS tax_type (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Tax rates (налоговые ставки)
CREATE TABLE IF NOT EXISTS tax_rate (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    tax_type_id BIGINT NOT NULL REFERENCES tax_type(id),
    rate NUMERIC(5,2) NOT NULL,  -- Процент 0-100
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_tax_rate_code ON tax_rate(code);
CREATE INDEX IF NOT EXISTS idx_tax_rate_type ON tax_rate(tax_type_id);

-- ============================================================
-- Функции
-- ============================================================

-- Рассчитать сумму налога
CREATE OR REPLACE FUNCTION calc_tax_amount(
    p_amount NUMERIC(18,2),
    p_tax_rate_id BIGINT
) RETURNS NUMERIC(18,2) AS $$
DECLARE
    v_rate NUMERIC(5,2);
BEGIN
    SELECT tr.rate INTO v_rate FROM tax_rate tr WHERE tr.id = p_tax_rate_id;
    RETURN p_amount * v_rate / 100;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- Налоговые ставки по типам
CREATE VIEW v_tax_rates_by_type AS
SELECT 
    tr.id, tr.code, tr.name, tt.name AS tax_type_name, tr.rate
FROM tax_rate tr
JOIN tax_type tt ON tt.id = tr.tax_type_id
ORDER BY tt.name, tr.rate;

-- Актуальные ставки НДС
CREATE VIEW v_vat_rates AS
SELECT * FROM tax_rate WHERE tax_type_id = 1;  -- НДС
