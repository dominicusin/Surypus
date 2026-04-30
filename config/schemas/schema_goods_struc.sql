-- =============================================================================
-- СТРУКТУРЫ ТОВАРОВ
-- Соответствуют Core.Goods.GoodsStruc
-- Аналог: PPOBJ_GOODSSTRUC
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_struc (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    goods_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_struc_goods ON goods_struc(goods_id);

CREATE TABLE IF NOT EXISTS goods_struc_item (
    id SERIAL PRIMARY KEY,
    struc_id INT NOT NULL REFERENCES goods_struc(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    qty NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (qty > 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_struc_item_struc ON goods_struc_item(struc_id);
CREATE INDEX idx_goods_struc_item_goods ON goods_struc_item(goods_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_struc_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_struc_update
    BEFORE UPDATE ON goods_struc
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_struc_timestamp();

CREATE TRIGGER trigger_goods_struc_item_update
    BEFORE UPDATE ON goods_struc_item
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_struc_timestamp();
