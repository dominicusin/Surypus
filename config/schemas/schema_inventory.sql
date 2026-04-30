-- ============================================================
-- Inventory Tables - Инвентаризации
-- Соответствует C++ inventry.cpp
-- ============================================================

-- Inventory (документ инвентаризации)
CREATE TABLE IF NOT EXISTS inventory_doc (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    op_kind_id BIGINT REFERENCES op_kind(id),
    warehouse_id BIGINT NOT NULL REFERENCES location(id),
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=STARTED, 2=COUNTED, 3=ANALYZED, 4=APPROVED, 5=COMPLETED, 6=CANCELLED
    flags INTEGER DEFAULT 0,
    memo TEXT,
    completed_by BIGINT,
    completed_at TIMESTAMPTZ,
    created_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code, warehouse_id)
);

-- Inventory lines (строки инвентаризации)
CREATE TABLE IF NOT EXISTS inventory_line (
    id BIGSERIAL PRIMARY KEY,
    inventory_id BIGINT NOT NULL REFERENCES inventory_doc(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    qtty_booked NUMERIC(18,6) NOT NULL DEFAULT 0,  -- Учётное количество
    qtty_fact NUMERIC(18,6) NOT NULL DEFAULT 0,    -- Фактическое количество
    price NUMERIC(18,4) NOT NULL DEFAULT 0,         -- Цена
    diff NUMERIC(18,6) NOT NULL DEFAULT 0,          -- Отклонение
    diff_amount NUMERIC(18,4) NOT NULL DEFAULT 0,   -- Сумма отклонения
    flags INTEGER DEFAULT 0,
    UNIQUE(inventory_id, line_no)
);

-- Индексы для инвентаризации
CREATE INDEX IF NOT EXISTS idx_inventory_doc_code ON inventory_doc(code);
CREATE INDEX IF NOT EXISTS idx_inventory_doc_dt ON inventory_doc(dt);
CREATE INDEX IF NOT EXISTS idx_inventory_doc_warehouse ON inventory_doc(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inventory_doc_status ON inventory_doc(status);

CREATE INDEX IF NOT EXISTS idx_inventory_line_inventory ON inventory_line(inventory_id);
CREATE INDEX IF NOT EXISTS idx_inventory_line_goods ON inventory_line(goods_id);

-- ============================================================
-- Функции для работы с инвентаризацией
-- ============================================================

-- Расчёт отклонений
CREATE OR REPLACE FUNCTION inventory_calc_diff(p_line_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_qty_booked NUMERIC(18,6);
    v_qty_fact NUMERIC(18,6);
    v_price NUMERIC(18,4);
    v_diff NUMERIC(18,6);
BEGIN
    SELECT il.qtty_booked, il.qtty_fact, il.price
    INTO v_qty_booked, v_qty_fact, v_price
    FROM inventory_line il
    WHERE il.id = p_line_id;
    
    v_diff := v_qty_fact - v_qty_booked;
    
    UPDATE inventory_line
    SET diff = v_diff, diff_amount = v_diff * price
    WHERE id = p_line_id;
END;
$$ LANGUAGE plpgsql;

-- Триггер на пересчёт отклонений
CREATE OR REPLACE FUNCTION inventory_line_diff_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM inventory_calc_diff(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_line_diff
    AFTER INSERT OR UPDATE ON inventory_line
    FOR EACH ROW EXECUTE FUNCTION inventory_line_diff_trigger();

-- Итоги инвентаризации
CREATE OR REPLACE FUNCTION inventory_summary(p_inventory_id BIGINT)
RETURNS TABLE (
    sum_booked NUMERIC(18,4),
    sum_fact NUMERIC(18,4),
    sum_diff NUMERIC(18,4),
    sum_surplus NUMERIC(18,4),
    sum_shortage NUMERIC(18,4),
    item_count BIGINT,
    surplus_count BIGINT,
    shortage_count BIGINT,
    exact_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(il.qtty_booked * il.price), 0) AS sum_booked,
        COALESCE(SUM(il.qtty_fact * il.price), 0) AS sum_fact,
        COALESCE(SUM(il.diff * il.price), 0) AS sum_diff,
        COALESCE(SUM(CASE WHEN il.diff > 0 THEN il.diff * il.price ELSE 0 END), 0) AS sum_surplus,
        COALESCE(SUM(CASE WHEN il.diff < 0 THEN -il.diff * il.price ELSE 0 END), 0) AS sum_shortage,
        COUNT(*)::BIGINT AS item_count,
        COUNT(CASE WHEN il.diff > 0 THEN 1 END)::BIGINT AS surplus_count,
        COUNT(CASE WHEN il.diff < 0 THEN 1 END)::BIGINT AS shortage_count,
        COUNT(CASE WHEN il.diff = 0 THEN 1 END)::BIGINT AS exact_count
    FROM inventory_line il
    WHERE il.inventory_id = p_inventory_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Результаты инвентаризации
CREATE OR REPLACE VIEW v_inventory_results AS
SELECT 
    id.id,
    id.code,
    id.dt,
    id.warehouse_id,
    l.name AS warehouse_name,
    id.status,
    (SELECT * FROM inventory_summary(id.id)).*,
    id.created_at
FROM inventory_doc id
JOIN location l ON l.id = id.warehouse_id
ORDER BY id.dt DESC;

-- Строки с излишками
CREATE OR REPLACE VIEW v_inventory_surplus AS
SELECT 
    id.code,
    id.dt,
    g.id AS goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    il.qtty_booked,
    il.qtty_fact,
    il.diff,
    il.price,
    il.diff_amount
FROM inventory_doc id
JOIN inventory_line il ON il.inventory_id = id.id
JOIN goods g ON g.id = il.goods_id
WHERE il.diff > 0
ORDER BY id.dt, il.diff_amount DESC;

-- Строки с недостачами
CREATE OR REPLACE VIEW v_inventory_shortage AS
SELECT 
    id.code,
    id.dt,
    g.id AS goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    il.qtty_booked,
    il.qtty_fact,
    il.diff,
    il.price,
    il.diff_amount
FROM inventory_doc id
JOIN inventory_line il ON il.inventory_id = id.id
JOIN goods g ON g.id = il.goods_id
WHERE il.diff < 0
ORDER BY id.dt, il.diff_amount DESC;

-- Точные совпадения
CREATE OR REPLACE VIEW v_inventory_exact AS
SELECT 
    id.code,
    id.dt,
    g.id AS goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    il.qtty_booked,
    il.qtty_fact,
    il.price
FROM inventory_doc id
JOIN inventory_line il ON il.inventory_id = id.id
JOIN goods g ON g.id = il.goods_id
WHERE il.diff = 0
ORDER BY id.dt, g.name;
