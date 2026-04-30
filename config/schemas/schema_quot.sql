-- =============================================================================
-- КОТИРОВКИ
-- Соответствуют Core.Pricing.Quot
-- Аналог: PPOBJ_QUOT
-- =============================================================================

CREATE TABLE IF NOT EXISTS quot (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    quot_kind_id INT NOT NULL,
    price NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (price >= 0),
    lower_price NUMERIC(18,4) DEFAULT 0,
    upper_price NUMERIC(18,4) DEFAULT 0,
    currency_id INT DEFAULT 1,
    flags INT DEFAULT 0,
    since TIMESTAMP NOT NULL DEFAULT NOW(),
    until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_quot_goods ON quot(goods_id);
CREATE INDEX idx_quot_quot_kind ON quot(quot_kind_id);
CREATE INDEX idx_quot_dates ON quot(since, until);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_quot_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quot_update
    BEFORE UPDATE ON quot
    FOR EACH ROW
    EXECUTE FUNCTION update_quot_timestamp();

-- FUNCTION: Получить актуальную цену
CREATE OR REPLACE FUNCTION get_quotes_price(p_goods_id INT, p_quot_kind_id INT)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_price NUMERIC(18,4);
BEGIN
    SELECT price INTO v_price
    FROM quot
    WHERE goods_id = p_goods_id 
      AND quot_kind_id = p_quot_kind_id
      AND since <= NOW()
      AND (until IS NULL OR until >= NOW())
    ORDER BY since DESC
    LIMIT 1;
    
    RETURN COALESCE(v_price, 0);
END;
$$ LANGUAGE plpgsql;
