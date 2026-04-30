-- =============================================================================
-- ОСТАТКИ ТОВАРОВ
-- Соответствуют Core.Warehouse.GoodsRest
-- Аналог: PPOBJ_GOODSREST
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_rest (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    location_id INT NOT NULL,
    rest NUMERIC(18,6) NOT NULL DEFAULT 0 CHECK (rest >= 0),
    reserved NUMERIC(18,6) NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    cost NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4) DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_goods_rest_reserved CHECK (reserved <= rest)
);

CREATE UNIQUE INDEX idx_goods_rest_unique ON goods_rest(goods_id, location_id);
CREATE INDEX idx_goods_rest_goods ON goods_rest(goods_id);
CREATE INDEX idx_goods_rest_location ON goods_rest(location_id);

-- FUNCTION: Обновить остаток товара
CREATE OR REPLACE FUNCTION update_goods_rest(p_goods_id INT, p_location_id INT, p_delta NUMERIC(18,6))
RETURNS VOID AS $$
BEGIN
    UPDATE goods_rest 
    SET rest = rest + p_delta,
        timestamp = CURRENT_TIMESTAMP
    WHERE goods_id = p_goods_id AND location_id = p_location_id;
    
    IF NOT FOUND THEN
        INSERT INTO goods_rest (goods_id, location_id, rest)
        VALUES (p_goods_id, p_location_id, p_delta);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Зарезервировать товар
CREATE OR REPLACE FUNCTION reserve_goods(p_goods_id INT, p_location_id INT, p_qty NUMERIC(18,6))
RETURNS BOOLEAN AS $$
DECLARE
    v_available NUMERIC(18,6);
BEGIN
    SELECT rest - reserved INTO v_available
    FROM goods_rest
    WHERE goods_id = p_goods_id AND location_id = p_location_id;
    
    IF v_available < p_qty THEN
        RETURN FALSE;
    END IF;
    
    UPDATE goods_rest 
    SET reserved = reserved + p_qty,
        timestamp = CURRENT_TIMESTAMP
    WHERE goods_id = p_goods_id AND location_id = p_location_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- VIEW: Доступные остатки
CREATE OR REPLACE VIEW v_available_goods_rest AS
SELECT 
    gr.id,
    gr.goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    gr.location_id,
    l.name AS location_name,
    gr.rest,
    gr.reserved,
    (gr.rest - gr.reserved) AS available,
    gr.cost,
    gr.price
FROM goods_rest gr
JOIN goods g ON g.id = gr.goods_id
JOIN location l ON l.id = gr.location_id
WHERE gr.rest > 0
ORDER BY g.name, l.name;
