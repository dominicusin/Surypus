-- =============================================================================
-- ТИПЫ ТОВАРОВ
-- Соответствуют Core.Goods.GoodsType
-- Аналог: PPOBJ_GOODSTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO goods_type (id, name, code) VALUES
(1, 'Товар', 'GOODS'),
(2, 'Услуга', 'SERVICE'),
(3, 'Материал', 'MATERIAL'),
(4, 'Полуфабрикат', 'SEMIFINISHED'),
(5, 'Оборудование', 'EQUIPMENT'),
(6, 'Комплект', 'KIT')
ON CONFLICT (id) DO NOTHING;
