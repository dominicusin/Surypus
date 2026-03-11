-- =============================================================================
-- СТРУКТУРА ТОВАРОВ (GOODS STRUCTURE)
-- Соответствуют Core.Goods.GoodsStructure
-- Аналог: PPOBJ_GOODSSTRUC
-- =============================================================================

-- =============================================================================
-- Goods Structure (Структура товара)
-- =============================================================================
CREATE TABLE IF NOT EXISTS goods_structure (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    flags INT DEFAULT 0,  -- 1:Архивная
    parent_id INT REFERENCES goods_structure(id),
    priority INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_structure_goods ON goods_structure(goods_id);
CREATE INDEX idx_goods_structure_parent ON goods_structure(parent_id);

-- =============================================================================
-- Goods Structure Item (Элемент структуры)
-- =============================================================================
CREATE TABLE IF NOT EXISTS goods_structure_item (
    id SERIAL PRIMARY KEY,
    structure_id INT NOT NULL REFERENCES goods_structure(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    price NUMERIC(18,4) DEFAULT 0,
    discount NUMERIC(5,2) DEFAULT 0 CHECK (discount >= 0 AND discount <= 100),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_structure_item_structure ON goods_structure_item(structure_id);
CREATE INDEX idx_goods_structure_item_goods ON goods_structure_item(goods_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION update_goods_structure_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_structure_update
    BEFORE UPDATE ON goods_structure
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_structure_timestamp();

CREATE TRIGGER trigger_goods_structure_item_update
    BEFORE UPDATE ON goods_structure_item
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_structure_timestamp();

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Получить структуру товара с компонентами
CREATE OR REPLACE FUNCTION get_goods_structure(p_goods_id INT)
RETURNS TABLE (
    structure_id INT,
    goods_id INT,
    component_id INT,
    component_name TEXT,
    quantity NUMERIC(18,6),
    price NUMERIC(18,4),
    discount NUMERIC(5,2),
    line_total NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        gs.id,
        gs.goods_id,
        gsi.goods_id,
        g.name,
        gsi.quantity,
        gsi.price,
        gsi.discount,
        (gsi.quantity * gsi.price * (1 - gsi.discount / 100))::NUMERIC(18,4)
    FROM goods_structure gs
    LEFT JOIN goods_structure_item gsi ON gsi.structure_id = gs.id
    LEFT JOIN goods g ON g.id = gsi.goods_id
    WHERE gs.goods_id = p_goods_id AND (gs.flags & 1) = 0
    ORDER BY gs.priority, gsi.id;
END;
$$ LANGUAGE plpgsql;

-- Рассчитать общую стоимость структуры
CREATE OR REPLACE FUNCTION calculate_structure_cost(p_structure_id INT)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_total NUMERIC(18,4);
BEGIN
    SELECT COALESCE(SUM(quantity * price * (1 - discount / 100)), 0)
    INTO v_total
    FROM goods_structure_item
    WHERE structure_id = p_structure_id;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- Проверить циклическую ссылку
CREATE OR REPLACE FUNCTION check_goods_structure_cycle(p_goods_id INT, p_component_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_result BOOLEAN := FALSE;
    v_current_id INT;
BEGIN
    -- Если компонент равен самому товару - это цикл
    IF p_goods_id = p_component_id THEN
        RETURN TRUE;
    END IF;
    
    -- Проверяем, не является ли компонент родителем товара
    v_current_id := p_component_id;
    WHILE v_current_id IS NOT NULL LOOP
        SELECT parent_id INTO v_current_id
        FROM goods_structure
        WHERE goods_id = v_current_id;
        
        IF v_current_id = p_goods_id THEN
            RETURN TRUE;
        END IF;
    END LOOP;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Структуры с количеством компонентов
CREATE OR REPLACE VIEW v_goods_structure_count AS
SELECT 
    gs.id,
    gs.goods_id,
    g.name AS goods_name,
    COUNT(gsi.id) AS component_count,
    calculate_structure_cost(gs.id) AS total_cost
FROM goods_structure gs
LEFT JOIN goods_structure_item gsi ON gsi.structure_id = gs.id
LEFT JOIN goods g ON g.id = gs.goods_id
WHERE (gs.flags & 1) = 0
GROUP BY gs.id, gs.goods_id, g.name;

-- Товары-комплекты
CREATE OR REPLACE VIEW v_goods_kits AS
SELECT 
    g.id,
    g.name,
    g.code,
    COUNT(gs.id) AS structure_count,
    SUM(calculate_structure_cost(gs.id)) AS kit_cost
FROM goods g
JOIN goods_structure gs ON gs.goods_id = g.id
WHERE (gs.flags & 1) = 0
GROUP BY g.id, g.name, g.code
HAVING COUNT(gs.id) > 0;
