-- =============================================================================
-- КОТИРОВКИ v2
-- Соответствуют Core.Pricing.Quot2
-- Аналог: PPOBJ_QUOT2
-- =============================================================================

CREATE TABLE IF NOT EXISTS quot2 (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    quot_kind_id INT NOT NULL,
    location_id INT DEFAULT 0,
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

CREATE INDEX idx_quot2_goods ON quot2(goods_id);
CREATE INDEX idx_quot2_quot_kind ON quot2(quot_kind_id);
CREATE INDEX idx_quot2_location ON quot2(location_id);
CREATE INDEX idx_quot2_dates ON quot2(since, until);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_quot2_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quot2_update
    BEFORE UPDATE ON quot2
    FOR EACH ROW
    EXECUTE FUNCTION update_quot2_timestamp();

-- FUNCTION: Получить актуальную цену
CREATE OR REPLACE FUNCTION get_current_price(p_goods_id INT, p_quot_kind_id INT, p_location_id INT DEFAULT 0)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_price NUMERIC(18,4);
BEGIN
    -- Сначала ищем для конкретного склада
    SELECT price INTO v_price
    FROM quot2
    WHERE goods_id = p_goods_id 
      AND quot_kind_id = p_quot_kind_id
      AND location_id = p_location_id
      AND since <= NOW()
      AND (until IS NULL OR until >= NOW())
    ORDER BY location_id DESC  -- Сначала ищем точное совпадение
    LIMIT 1;
    
    -- Если нет, ищем общую цену
    IF NOT FOUND THEN
        SELECT price INTO v_price
        FROM quot2
        WHERE goods_id = p_goods_id 
          AND quot_kind_id = p_quot_kind_id
          AND location_id = 0
          AND since <= NOW()
          AND (until IS NULL OR until >= NOW())
        LIMIT 1;
    END IF;
    
    RETURN COALESCE(v_price, 0);
END;
$$ LANGUAGE plpgsql;
