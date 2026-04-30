-- =============================================================================
-- АРТИКУЛЫ ТОВАРОВ
-- Соответствуют Core.Goods.GoodsArCode
-- Аналог: PPOBJ_GOODSARCODE
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_ar_code (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    code VARCHAR(128) NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_ar_code_goods ON goods_ar_code(goods_id);
CREATE UNIQUE INDEX idx_goods_ar_code_unique ON goods_ar_code(goods_id, code);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_ar_code_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_ar_code_update
    BEFORE UPDATE ON goods_ar_code
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_ar_code_timestamp();
