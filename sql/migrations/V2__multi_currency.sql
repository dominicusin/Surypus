-- V2__multi_currency.sql
-- Multi-currency support

-- Add currency fields to existing tables
ALTER TABLE payments ADD COLUMN IF NOT EXISTS currency_id INT REFERENCES currencies(currency_id);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS exchange_rate DECIMAL(15, 6) DEFAULT 1;
ALTER TABLE goods ADD COLUMN IF NOT EXISTS currency_id INT REFERENCES currencies(currency_id);
ALTER TABLE bills ADD COLUMN IF NOT EXISTS currency_id INT REFERENCES currencies(currency_id);
ALTER TABLE bills ADD COLUMN IF NOT EXISTS bill_total_base DECIMAL(15, 2);

-- Currency rates history
CREATE TABLE IF NOT EXISTS currency_rates (
    rate_id SERIAL PRIMARY KEY,
    currency_id INT NOT NULL REFERENCES currencies(currency_id),
    rate_date DATE NOT NULL,
    exchange_rate DECIMAL(15, 6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(currency_id, rate_date)
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_currency_rates_date ON currency_rates(rate_date);

-- Insert default currencies
INSERT INTO currencies (currency_code, currency_name, currency_symbol, exchange_rate, is_base, active)
VALUES 
    ('RUB', 'Российский рубль', '₽', 1, TRUE, TRUE),
    ('USD', 'Доллар США', '$', 92.5, FALSE, TRUE),
    ('EUR', 'Евро', '€', 100.2, FALSE, TRUE),
    ('CNY', 'Китайский юань', '¥', 12.8, FALSE, TRUE),
    ('KZT', 'Казахский тенге', '₸', 0.2, FALSE, TRUE)
ON CONFLICT (currency_code) DO NOTHING;

-- Function to convert amount to base currency
CREATE OR REPLACE FUNCTION convert_to_base_currency(
    p_amount DECIMAL(15, 2),
    p_currency_id INT,
    p_date DATE DEFAULT CURRENT_DATE
) RETURNS DECIMAL(15, 2) AS $$
DECLARE
    v_rate DECIMAL(15, 6);
    v_base_rate DECIMAL(15, 6);
BEGIN
    -- Get rate for the given currency
    SELECT exchange_rate INTO v_rate
    FROM currency_rates
    WHERE currency_id = p_currency_id 
      AND rate_date <= p_date
    ORDER BY rate_date DESC
    LIMIT 1;
    
    -- If no historical rate, use current rate
    IF v_rate IS NULL THEN
        SELECT c.exchange_rate INTO v_rate
        FROM currencies c
        WHERE c.currency_id = p_currency_id;
    END IF;
    
    -- Get base currency rate
    SELECT c.exchange_rate INTO v_base_rate
    FROM currencies c
    WHERE c.is_base = TRUE;
    
    IF v_base_rate IS NULL THEN
        v_base_rate := 1;
    END IF;
    
    -- Convert to base currency
    RETURN p_amount * (v_rate / v_base_rate);
END;
$$ LANGUAGE plpgsql;

-- Function to get currency rate
CREATE OR REPLACE FUNCTION get_currency_rate(
    p_currency_id INT,
    p_date DATE DEFAULT CURRENT_DATE
) RETURNS DECIMAL(15, 6) AS $$
DECLARE
    v_rate DECIMAL(15, 6);
BEGIN
    SELECT exchange_rate INTO v_rate
    FROM currency_rates
    WHERE currency_id = p_currency_id 
      AND rate_date <= p_date
    ORDER BY rate_date DESC
    LIMIT 1;
    
    IF v_rate IS NULL THEN
        SELECT c.exchange_rate INTO v_rate
        FROM currencies c
        WHERE c.currency_id = p_currency_id;
    END IF;
    
    RETURN COALESCE(v_rate, 1);
END;
$$ LANGUAGE plpgsql;
