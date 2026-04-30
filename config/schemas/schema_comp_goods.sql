-- =============================================================================
-- ТОВАРЫ С СОСТАВЛЯЮЩИМИ
-- Соответствуют Core.Goods.CompGoods
-- Аналог: PPOBJ_COMPGOODS
-- =============================================================================

CREATE TABLE IF NOT EXISTS comp_goods (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL UNIQUE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS comp_goods_item (
    id SERIAL PRIMARY KEY,
    comp_goods_id INT NOT NULL REFERENCES comp_goods(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    qty NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (qty > 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comp_goods_item_comp ON comp_goods_item(comp_goods_id);
CREATE INDEX idx_comp_goods_item_goods ON comp_goods_item(goods_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_comp_goods_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_comp_goods_update
    BEFORE UPDATE ON comp_goods
    FOR EACH ROW
    EXECUTE FUNCTION update_comp_goods_timestamp();

CREATE TRIGGER trigger_comp_goods_item_update
    BEFORE UPDATE ON comp_goods_item
    FOR EACH ROW
    EXECUTE FUNCTION update_comp_goods_timestamp();

-- FUNCTION: Рассчитать стоимость составляющих
CREATE OR REPLACE FUNCTION calculate_comp_goods_cost(p_comp_goods_id INT)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_cost NUMERIC(18,4);
BEGIN
    SELECT COALESCE(SUM(cgi.qty * COALESCE(gd.price, 0)), 0)
    INTO v_cost
    FROM comp_goods_item cgi
    JOIN goods gd ON gd.id = cgi.goods_id
    WHERE cgi.comp_goods_id = p_comp_goods_id;
    
    RETURN v_cost;
END;
$$ LANGUAGE plpgsql;
