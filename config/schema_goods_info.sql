-- =============================================================================
-- ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ О ТОВАРАХ
-- Соответствуют Core.Goods.GoodsInfo
-- Аналог: PPOBJ_GOODSINFO
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_info (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    info_type INT NOT NULL,
    value TEXT,
    expiry TIMESTAMP,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_info_goods ON goods_info(goods_id);
CREATE INDEX idx_goods_info_type ON goods_info(info_type);
CREATE UNIQUE INDEX idx_goods_info_unique ON goods_info(goods_id, info_type);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_info_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_info_update
    BEFORE UPDATE ON goods_info
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_info_timestamp();
