-- ============================================================
-- Production Tables - Производство (MRP)
-- Соответствует C++ mrp.cpp
-- ============================================================

-- Work orders (производственные заказы)
CREATE TABLE IF NOT EXISTS work_order (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    due_date DATE NOT NULL,
    product_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,6) NOT NULL,
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=RELEASED, 2=INPROGRESS, 3=COMPLETED, 4=CANCELLED
    flags INTEGER DEFAULT 0,
    output_qtty NUMERIC(18,6) DEFAULT 0,
    start_date DATE,
    memo TEXT,
    created_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Work order lines (материалы для производства)
CREATE TABLE IF NOT EXISTS work_order_line (
    id BIGSERIAL PRIMARY KEY,
    work_order_id BIGINT NOT NULL REFERENCES work_order(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,6) NOT NULL,
    issued_qtty NUMERIC(18,6) DEFAULT 0,
    consumed_qtty NUMERIC(18,6) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(work_order_id, line_no)
);

-- Bill of Materials (спецификации)
CREATE TABLE IF NOT EXISTS bom (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES goods(id),
    component_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,6) NOT NULL,
    yield NUMERIC(5,2),  -- Процент выхода
    flags INTEGER DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, component_id, valid_from)
);

-- Production sessions (производственные сессии)
CREATE TABLE IF NOT EXISTS production_session (
    id BIGSERIAL PRIMARY KEY,
    work_order_id BIGINT REFERENCES work_order(id),
    dt DATE NOT NULL,
    output_qtty NUMERIC(18,6) NOT NULL,
    output_goods_id BIGINT REFERENCES goods(id),
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Production session lines (потребление материалов)
CREATE TABLE IF NOT EXISTS production_session_line (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES production_session(id) ON DELETE CASCADE,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,6) NOT NULL
);

-- Индексы для производства
CREATE INDEX IF NOT EXISTS idx_work_order_code ON work_order(code);
CREATE INDEX IF NOT EXISTS idx_work_order_dt ON work_order(dt);
CREATE INDEX IF NOT EXISTS idx_work_order_product ON work_order(product_id);
CREATE INDEX IF NOT EXISTS idx_work_order_status ON work_order(status);

CREATE INDEX IF NOT EXISTS idx_work_order_line_order ON work_order_line(work_order_id);
CREATE INDEX IF NOT EXISTS idx_work_order_line_goods ON work_order_line(goods_id);

CREATE INDEX IF NOT EXISTS idx_bom_product ON bom(product_id);
CREATE INDEX IF NOT EXISTS idx_bom_component ON bom(component_id);

-- ============================================================
-- Функции для производства
-- ============================================================

-- Рассчитать потребность в материалах по спецификации
CREATE OR REPLACE FUNCTION calc_material_need(
    p_product_id BIGINT,
    p_qtty NUMERIC(18,6)
) RETURNS TABLE (goods_id BIGINT, need_qtty NUMERIC(18,6)) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.component_id,
        p_qtty * b.qtty * COALESCE(100.0 / NULLIF(b.yield, 0), 1.0)
    FROM bom b
    WHERE b.product_id = p_product_id
        AND (b.valid_from IS NULL OR b.valid_from <= CURRENT_DATE)
        AND (b.valid_to IS NULL OR b.valid_to >= CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

-- MRP расчёт (упрощённый)
CREATE OR REPLACE FUNCTION mrp_calculate(
    p_needs JSON,  -- [{"goods_id": 1, "need": 100}]
    p_date DATE
) RETURNS TABLE (goods_id BIGINT, need_qtty NUMERIC(18,6), on_hand NUMERIC(18,6), on_order NUMERIC(18,6), planned_order NUMERIC(18,6)) AS $$
DECLARE
    v_needs JSONB;
    v_item JSONB;
    v_goods_id BIGINT;
    v_need NUMERIC(18,6);
    v_on_hand NUMERIC(18,6);
    v_on_order NUMERIC(18,6);
    v_planned NUMERIC(18,6);
BEGIN
    v_needs := p_needs::JSONB;
    
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_needs)
    LOOP
        v_goods_id := (v_item->>'goods_id')::BIGINT;
        v_need := (v_item->>'need')::NUMERIC(18,6);
        
        -- Получить остаток на складе
        SELECT COALESCE(SUM(s.qtty), 0) INTO v_on_hand
        FROM stock s
        WHERE s.goods_id = v_goods_id;
        
        -- Получить количество в заказах
        SELECT COALESCE(SUM(ol.qtty - ol.shipped_qtty), 0) INTO v_on_order
        FROM orders o
        JOIN order_line ol ON ol.order_id = o.id
        WHERE ol.goods_id = v_goods_id
            AND o.otype = 0  -- SUPPLIER
            AND o.status NOT IN (5, 6);  -- NOT COMPLETED, NOT CANCELLED
        
        -- Рассчитать планируемый заказ
        v_planned := GREATEST(v_need - v_on_hand - v_on_order, 0);
        
        RETURN QUERY SELECT v_goods_id, v_need, v_on_hand, v_on_order, v_planned;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Запуск производственного заказа
CREATE OR REPLACE FUNCTION work_order_release(p_order_id BIGINT, p_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE work_order 
    SET status = 1, start_date = p_date, updated_at = NOW()
    WHERE id = p_order_id AND status = 0;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Завершение производственного заказа
CREATE OR REPLACE FUNCTION work_order_complete(p_order_id BIGINT, p_output_qtty NUMERIC(18,6))
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE work_order 
    SET status = 3, output_qtty = p_output_qtty, updated_at = NOW()
    WHERE id = p_order_id AND status IN (1, 2);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Активные производственные заказы
CREATE OR REPLACE VIEW v_active_work_orders AS
SELECT 
    wo.id, wo.code, wo.dt, wo.due_date,
    g.id AS product_id, g.name AS product_name,
    wo.qtty, wo.output_qtty, wo.status,
    wo.qtty - wo.output_qtty AS remaining_qtty
FROM work_order wo
JOIN goods g ON g.id = wo.product_id
WHERE wo.status IN (1, 2)  -- RELEASED, INPROGRESS
ORDER BY wo.due_date;

-- Спецификации (Bill of Materials)
CREATE OR REPLACE VIEW v_bom AS
SELECT 
    b.id, b.product_id, gp.name AS product_name,
    b.component_id, gc.name AS component_name,
    b.qtty, b.yield, b.flags,
    b.valid_from, b.valid_to
FROM bom b
JOIN goods gp ON gp.id = b.product_id
JOIN goods gc ON gc.id = b.component_id
WHERE (b.valid_from IS NULL OR b.valid_from <= CURRENT_DATE)
    AND (b.valid_to IS NULL OR b.valid_to >= CURRENT_DATE)
ORDER BY gp.name, b.component_id;

-- Потребность в материалах для заказа
CREATE OR REPLACE VIEW v_work_order_materials AS
SELECT 
    wo.id AS work_order_id, wo.code AS work_order_code,
    wol.goods_id, g.name AS goods_name,
    wol.qtty AS required_qtty,
    wol.issued_qtty, wol.consumed_qtty,
    wol.qtty - wol.issued_qtty AS remaining_to_issue
FROM work_order wo
JOIN work_order_line wol ON wol.work_order_id = wo.id
JOIN goods g ON g.id = wol.goods_id
WHERE wo.status IN (1, 2)  -- RELEASED, INPROGRESS
ORDER BY wo.due_date, wol.line_no;

-- Просроченные производственные заказы
CREATE OR REPLACE VIEW v_overdue_work_orders AS
SELECT 
    wo.id, wo.code, wo.dt, wo.due_date,
    g.name AS product_name,
    wo.qtty, wo.output_qtty,
    CURRENT_DATE - wo.due_date AS days_overdue
FROM work_order wo
JOIN goods g ON g.id = wo.product_id
WHERE wo.due_date < CURRENT_DATE 
    AND wo.status NOT IN (3, 4)  -- NOT COMPLETED, NOT CANCELLED
ORDER BY wo.due_date;