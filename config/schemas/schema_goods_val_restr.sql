-- =============================================================================
-- ОГРАНИЧЕНИЯ ТОВАРНЫХ ВЕЛИЧИН
-- Соответствуют Core.Goods.GoodsValRestr
-- Аналог: PPOBJ_GOODSVALRESTR
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_val_restr (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    goods_id INT NOT NULL,
    loc_id INT DEFAULT 0,
    value_type INT NOT NULL,  -- 1:Quantity, 2:Weight, 3:Volume, 4:Price, 5:Discount, 6:Sum
    min_value NUMERIC(18,6) NOT NULL,
    max_value NUMERIC(18,6) NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_gvr_range CHECK (min_value <= max_value)
);

CREATE INDEX idx_gvr_goods ON goods_val_restr(goods_id);
CREATE INDEX idx_gvr_location ON goods_val_restr(loc_id);
CREATE INDEX idx_gvr_type ON goods_val_restr(value_type);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_goods_val_restr_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_goods_val_restr_update
    BEFORE UPDATE ON goods_val_restr
    FOR EACH ROW
    EXECUTE FUNCTION update_goods_val_restr_timestamp();

-- FUNCTION: Проверить значение на соответствие ограничению
CREATE OR REPLACE FUNCTION check_goods_value(p_goods_id INT, p_loc_id INT, p_value_type INT, p_value NUMERIC(18,6))
RETURNS BOOLEAN AS $$
DECLARE
    v_min NUMERIC(18,6);
    v_max NUMERIC(18,6);
BEGIN
    -- Сначала ищем ограничение для конкретного склада
    SELECT min_value, max_value INTO v_min, v_max
    FROM goods_val_restr
    WHERE goods_id = p_goods_id 
      AND loc_id = p_loc_id 
      AND value_type = p_value_type
    LIMIT 1;
    
    -- Если нет, ищем общее ограничение для товара
    IF NOT FOUND THEN
        SELECT min_value, max_value INTO v_min, v_max
        FROM goods_val_restr
        WHERE goods_id = p_goods_id 
          AND loc_id = 0 
          AND value_type = p_value_type
        LIMIT 1;
    END IF;
    
    -- Если ограничение найдено, проверяем
    IF FOUND THEN
        RETURN p_value >= v_min AND p_value <= v_max;
    END IF;
    
    -- Нет ограничений - разрешаем
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- VIEW: Все активные ограничения с именами товаров
CREATE OR REPLACE VIEW v_goods_val_restr_with_names AS
SELECT 
    gvr.id,
    gvr.name,
    gvr.goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    gvr.loc_id,
    l.name AS location_name,
    gvr.value_type,
    CASE gvr.value_type
        WHEN 1 THEN 'Quantity'
        WHEN 2 THEN 'Weight'
        WHEN 3 THEN 'Volume'
        WHEN 4 THEN 'Price'
        WHEN 5 THEN 'Discount'
        WHEN 6 THEN 'Sum'
    END AS value_type_name,
    gvr.min_value,
    gvr.max_value
FROM goods_val_restr gvr
LEFT JOIN goods g ON g.id = gvr.goods_id
LEFT JOIN location l ON l.id = gvr.loc_id;
