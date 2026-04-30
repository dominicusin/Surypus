-- =============================================================================
-- ГРУППЫ ТОВАРОВ
-- Соответствуют Core.Goods.GoodsGroup
-- Аналог: PPOBJ_GOODSGROUP
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_group (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id INT DEFAULT 0,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_group_parent ON goods_group(parent_id);
CREATE INDEX idx_goods_group_code ON goods_group(code);

-- DEFAULT DATA
INSERT INTO goods_group (id, name, parent_id, code) VALUES
(1, 'Все товары', 0, 'ALL'),
(2, 'Продукты питания', 1, 'FOOD'),
(3, 'Напитки', 1, 'DRINKS'),
(4, 'Промышленные товары', 1, 'INDUSTRIAL'),
(5, 'Молочные продукты', 2, 'DAIRY'),
(6, 'Мясо и птица', 2, 'MEAT'),
(7, 'Хлебобулочные изделия', 2, 'BAKERY'),
(8, 'Алкогольные напитки', 3, 'ALCOHOL'),
(9, 'Безалкогольные напитки', 3, 'NONALCOHOL')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_group_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_group_update
    BEFORE UPDATE ON goods_group
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_group_timestamp();

-- VIEW: Иерархия групп товаров
CREATE OR REPLACE VIEW v_goods_group_hierarchy AS
WITH RECURSIVE gg_hierarchy AS (
    SELECT 
        id,
        name,
        parent_id,
        code,
        0 AS level,
        ARRAY[code] AS path
    FROM goods_group
    WHERE parent_id = 0
    
    UNION ALL
    
    SELECT 
        g.id,
        g.name,
        g.parent_id,
        g.code,
        h.level + 1,
        h.path || g.code
    FROM goods_group g
    JOIN gg_hierarchy h ON h.id = g.parent_id
)
SELECT * FROM gg_hierarchy
ORDER BY code;
