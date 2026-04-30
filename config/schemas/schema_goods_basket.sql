-- =============================================================================
-- ТОВАРНЫЕ КОРЗИНЫ
-- Соответствуют Core.Trade.CounterItem (GoodsBasket)
-- Аналог: PPOBJ_GOODSBASKET
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_basket (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    owner_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_basket_owner ON goods_basket(owner_id);

CREATE TABLE IF NOT EXISTS goods_basket_item (
    id SERIAL PRIMARY KEY,
    basket_id INT NOT NULL REFERENCES goods_basket(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_basket_item_basket ON goods_basket_item(basket_id);
CREATE INDEX idx_goods_basket_item_goods ON goods_basket_item(goods_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_basket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_basket_update
    BEFORE UPDATE ON goods_basket
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_basket_timestamp();

CREATE TRIGGER trigger_goods_basket_item_update
    BEFORE UPDATE ON goods_basket_item
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_basket_timestamp();