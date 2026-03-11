-- =============================================================================
-- ВАЛЮТЫ
-- Соответствуют Core.Finance.Currency
-- Аналог: PPOBJ_CURRENCY
-- =============================================================================

CREATE TABLE IF NOT EXISTS currency (
    id SERIAL PRIMARY KEY,
    code CHAR(3) NOT NULL,
    name VARCHAR(256) NOT NULL,
    symbol VARCHAR(8),
    iso_num INT DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_currency_code ON currency(code);
CREATE UNIQUE INDEX idx_currency_iso_num ON currency(iso_num) WHERE iso_num > 0;

-- DEFAULT DATA
INSERT INTO currency (id, code, name, symbol, iso_num) VALUES
(1, 'RUB', 'Российский рубль', '₽', 643),
(2, 'USD', 'Доллар США', '$', 840),
(3, 'EUR', 'Евро', '€', 978),
(4, 'GBP', 'Фунт стерлингов', '£', 826),
(5, 'CNY', 'Китайский юань', '¥', 156),
(6, 'KZT', 'Казахский тенге', '₸', 398),
(7, 'BYR', 'Белорусский рубль', 'Br', 933),
(8, 'UAH', 'Украинская гривна', '₴', 980),
(9, 'AZN', 'Азербайджанский манат', '₼', 944)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS currency_rate (
    id SERIAL PRIMARY KEY,
    currency_id INT NOT NULL,
    rate_type_id INT NOT NULL DEFAULT 1,
    rate NUMERIC(18,8) NOT NULL DEFAULT 1,
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_currency_rate_positive CHECK (rate > 0)
);

CREATE INDEX idx_currency_rate_currency ON currency_rate(currency_id);
CREATE INDEX idx_currency_rate_date ON currency_rate(date);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_currency_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_currency_update
    BEFORE UPDATE ON currency
    FOR EACH ROW
    EXECUTE FUNCTION update_currency_timestamp();

CREATE TRIGGER trigger_currency_rate_update
    BEFORE UPDATE ON currency_rate
    FOR EACH ROW
    EXECUTE FUNCTION update_currency_timestamp();

-- FUNCTION: Получить курс валюты на дату
CREATE OR REPLACE FUNCTION get_currency_rate(p_currency_id INT, p_date DATE)
RETURNS NUMERIC(18,8) AS $$
DECLARE
    v_rate NUMERIC(18,8);
BEGIN
    SELECT rate INTO v_rate
    FROM currency_rate
    WHERE currency_id = p_currency_id AND date <= p_date
    ORDER BY date DESC
    LIMIT 1;
    
    RETURN COALESCE(v_rate, 1);
END;
$$ LANGUAGE plpgsql;