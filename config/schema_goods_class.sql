-- =============================================================================
-- ОТРАСЛЕВЫЕ КЛАССЫ ТОВАРОВ
-- Соответствуют Core.Goods.GoodsClass
-- Аналог: PPOBJ_GOODSCLASS
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_class (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    parent_id INT DEFAULT 0,
    flags INT DEFAULT 0,
    config JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_class_parent ON goods_class(parent_id);
CREATE UNIQUE INDEX idx_goods_class_symb ON goods_class(symb) WHERE symb IS NOT NULL;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_class_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_class_update
    BEFORE UPDATE ON goods_class
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_class_timestamp();

-- DEFAULT DATA
INSERT INTO goods_class (id, name, symb) VALUES
(1, 'Продовольствие', 'FOOD'),
(2, 'Промышленные товары', 'INDUSTRIAL'),
(3, 'Алкоголь', 'ALCOHOL'),
(4, 'Табачная продукция', 'TOBACCO'),
(5, 'Лекарственные средства', 'MEDICINE')
ON CONFLICT (id) DO NOTHING;
