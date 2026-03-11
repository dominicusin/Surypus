-- =============================================================================
-- ПРАЙС-ЛИСТЫ
-- Соответствуют Core.Pricing.PriceList
-- Аналог: PPOBJ_PRICELIST
-- =============================================================================

CREATE TABLE IF NOT EXISTS price_list (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    currency_id INT DEFAULT 1,
    valid_from DATE NOT NULL,
    valid_to DATE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_price_list_dates CHECK (valid_from <= valid_to OR valid_to IS NULL)
);

CREATE INDEX idx_price_list_dates ON price_list(valid_from, valid_to);
CREATE INDEX idx_price_list_currency ON price_list(currency_id);

-- TABLE: Строки прайс-листа
CREATE TABLE IF NOT EXISTS price_list_line (
    id SERIAL PRIMARY KEY,
    price_list_id INT NOT NULL REFERENCES price_list(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    price NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (price >= 0),
    min_qty NUMERIC(18,6) DEFAULT 1,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_price_list_line_price_list ON price_list_line(price_list_id);
CREATE INDEX idx_price_list_line_goods ON price_list_line(goods_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_price_list_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_price_list_update
    BEFORE UPDATE ON price_list
    FOR EACH ROW
    EXECUTE FUNCTION update_price_list_timestamp();

CREATE TRIGGER trigger_price_list_line_update
    BEFORE UPDATE ON price_list_line
    FOR EACH ROW
    EXECUTE FUNCTION update_price_list_timestamp();

-- FUNCTION: Получить цену из прайс-листа
CREATE OR REPLACE FUNCTION get_price_list_price(p_price_list_id INT, p_goods_id INT, p_qty NUMERIC(18,6))
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_price NUMERIC(18,4);
BEGIN
    SELECT pll.price INTO v_price
    FROM price_list_line pll
    JOIN price_list pl ON pl.id = pll.price_list_id
    WHERE pll.price_list_id = p_price_list_id
      AND pll.goods_id = p_goods_id
      AND (pll.min_qty IS NULL OR pll.min_qty <= p_qty)
      AND (pl.valid_to IS NULL OR pl.valid_to >= CURRENT_DATE)
    ORDER BY COALESCE(pll.min_qty, 1) DESC
    LIMIT 1;
    
    RETURN COALESCE(v_price, 0);
END;
$$ LANGUAGE plpgsql;
