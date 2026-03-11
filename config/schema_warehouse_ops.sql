-- ============================================================
-- Warehouse Operations Tables - Складские операции
-- ============================================================

-- Warehouse zones (зоны склада)
CREATE TABLE IF NOT EXISTS warehouse_zone (
    id BIGSERIAL PRIMARY KEY,
    warehouse_id BIGINT NOT NULL REFERENCES location(id),
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    ztype SMALLINT NOT NULL,  -- 0=RECEIVING, 1=STORAGE, 2=PICKING, 3=SHIPPING, 4=BUFFER, 5=RETURN
    capacity NUMERIC(18,2) NOT NULL DEFAULT 0,
    used_capacity NUMERIC(18,2) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(warehouse_id, code)
);

-- Warehouse cells (ячейки склада)
CREATE TABLE IF NOT EXISTS warehouse_cell (
    id BIGSERIAL PRIMARY KEY,
    zone_id BIGINT NOT NULL REFERENCES warehouse_zone(id),
    code VARCHAR(32) NOT NULL,
    ctype SMALLINT NOT NULL,  -- 0=PALLET, 1=BOX, 2=SHELF, 3=FLOOR, 4=RACK, 5=COLD
    capacity NUMERIC(18,2) DEFAULT 0,
    max_weight NUMERIC(18,2) DEFAULT 0,
    status SMALLINT DEFAULT 0,  -- 0=EMPTY, 1=PARTIAL, 2=FULL, 3=BLOCKED, 4=MAINTENANCE
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(zone_id, code)
);

-- Zone transfers (перемещения между зонами)
CREATE TABLE IF NOT EXISTS zone_transfer (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    from_zone_id BIGINT NOT NULL REFERENCES warehouse_zone(id),
    to_zone_id BIGINT NOT NULL REFERENCES warehouse_zone(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,6) NOT NULL,
    status SMALLINT DEFAULT 0,  -- 0=PENDING, 1=IN_PROGRESS, 2=COMPLETED, 3=CANCELLED
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(code)
);

-- Cell contents (содержимое ячеек)
CREATE TABLE IF NOT EXISTS cell_content (
    id BIGSERIAL PRIMARY KEY,
    cell_id BIGINT NOT NULL REFERENCES warehouse_cell(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    lot_id BIGINT REFERENCES lot(id),
    qtty NUMERIC(18,6) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cell_id, goods_id, lot_id)
);

-- Индексы для складских операций
CREATE INDEX IF NOT EXISTS idx_warehouse_zone_warehouse ON warehouse_zone(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_zone_code ON warehouse_zone(code);

CREATE INDEX IF NOT EXISTS idx_warehouse_cell_zone ON warehouse_cell(zone_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_cell_code ON warehouse_cell(code);
CREATE INDEX IF NOT EXISTS idx_warehouse_cell_status ON warehouse_cell(status);

CREATE INDEX IF NOT EXISTS idx_zone_transfer_code ON zone_transfer(code);
CREATE INDEX IF NOT EXISTS idx_zone_transfer_date ON zone_transfer(dt);
CREATE INDEX IF NOT EXISTS idx_zone_transfer_zones ON zone_transfer(from_zone_id, to_zone_id);

CREATE INDEX IF NOT EXISTS idx_cell_content_cell ON cell_content(cell_id);
CREATE INDEX IF NOT EXISTS idx_cell_content_goods ON cell_content(goods_id);

-- ============================================================
-- Функции для складских операций
-- ============================================================

-- Расчёт использования зоны
CREATE OR REPLACE FUNCTION calc_zone_usage_percent(p_zone_id BIGINT)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    v_capacity NUMERIC(18,2);
    v_used NUMERIC(18,2);
BEGIN
    SELECT wz.capacity, wz.used_capacity INTO v_capacity, v_used
    FROM warehouse_zone wz WHERE wz.id = p_zone_id;
    
    IF v_capacity = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN v_used / v_capacity * 100;
END;
$$ LANGUAGE plpgsql;

-- Размещение товара в зоне
CREATE OR REPLACE FUNCTION place_in_zone(
    p_zone_id BIGINT,
    p_qtty NUMERIC(18,2)
) RETURNS BOOLEAN AS $$
DECLARE
    v_capacity NUMERIC(18,2);
    v_used NUMERIC(18,2);
BEGIN
    SELECT wz.capacity, wz.used_capacity INTO v_capacity, v_used
    FROM warehouse_zone wz WHERE wz.id = p_zone_id;
    
    IF v_used + p_qtty > v_capacity THEN
        RETURN FALSE;
    END IF;
    
    UPDATE warehouse_zone SET used_capacity = used_capacity + p_qtty WHERE id = p_zone_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Перемещение между зонами
CREATE OR REPLACE FUNCTION transfer_between_zones(
    p_from_zone_id BIGINT,
    p_to_zone_id BIGINT,
    p_goods_id BIGINT,
    p_qtty NUMERIC(18,6)
) RETURNS BOOLEAN AS $$
BEGIN
    -- Проверить доступность
    IF NOT place_in_zone(p_to_zone_id, p_qtty) THEN
        RETURN FALSE;
    END IF;
    
    -- Освободить исходную зону
    UPDATE warehouse_zone SET used_capacity = used_capacity - p_qtty 
    WHERE id = p_from_zone_id AND used_capacity >= p_qtty;
    
    -- Записать перемещение
    INSERT INTO zone_transfer (code, dt, from_zone_id, to_zone_id, goods_id, qtty, status)
    VALUES (to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || p_goods_id, 
            CURRENT_DATE, p_from_zone_id, p_to_zone_id, p_goods_id, p_qtty, 2);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Найти свободную ячейку
CREATE OR REPLACE FUNCTION find_free_cell(
    p_zone_id BIGINT,
    p_goods_id BIGINT,
    p_qtty NUMERIC(18,6)
) RETURNS BIGINT AS $$
DECLARE
    v_cell_id BIGINT;
BEGIN
    SELECT wc.id INTO v_cell_id
    FROM warehouse_cell wc
    WHERE wc.zone_id = p_zone_id 
        AND wc.status IN (0, 1)  -- EMPTY или PARTIAL
        AND wc.capacity >= p_qtty
    ORDER BY wc.status, wc.code
    LIMIT 1;
    
    RETURN v_cell_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Загрузка зон
CREATE OR REPLACE VIEW v_zone_usage AS
SELECT 
    wz.id, wz.warehouse_id, l.name AS warehouse_name,
    wz.code, wz.name, wz.ztype, wz.capacity, wz.used_capacity,
    CASE WHEN wz.capacity = 0 THEN 0 
         ELSE wz.used_capacity * 100.0 / wz.capacity 
    END AS usage_percent,
    wz.capacity - wz.used_capacity AS free_capacity
FROM warehouse_zone wz
JOIN location l ON l.id = wz.warehouse_id
ORDER BY wz.warehouse_id, wz.code;

-- Свободные ячейки
CREATE OR REPLACE VIEW v_free_cells AS
SELECT 
    wc.id, wc.zone_id, wz.name AS zone_name,
    wc.code, wc.ctype, wc.capacity, wc.max_weight
FROM warehouse_cell wc
JOIN warehouse_zone wz ON wz.id = wc.zone_id
WHERE wc.status = 0  -- EMPTY
ORDER BY wz.name, wc.code;

-- Ячейки с товарами
CREATE OR REPLACE VIEW v_cell_contents AS
SELECT 
    cc.id, cc.cell_id, wc.code AS cell_code,
    cc.goods_id, g.name AS goods_name,
    cc.lot_id, cc.qtty,
    cc.updated_at
FROM cell_content cc
JOIN warehouse_cell wc ON wc.id = cc.cell_id
JOIN goods g ON g.id = cc.goods_id
ORDER BY wc.code, g.name;

-- Перемещения за период
CREATE OR REPLACE VIEW v_zone_transfers AS
SELECT 
    zt.id, zt.code, zt.dt,
    wz_from.code AS from_zone, wz_to.code AS to_zone,
    g.name AS goods_name, zt.qtty, zt.status,
    CASE zt.status
        WHEN 0 THEN 'Ожидает'
        WHEN 1 THEN 'В процессе'
        WHEN 2 THEN 'Завершено'
        WHEN 3 THEN 'Отменено'
    END AS status_name
FROM zone_transfer zt
JOIN warehouse_zone wz_from ON wz_from.id = zt.from_zone_id
JOIN warehouse_zone wz_to ON wz_to.id = zt.to_zone_id
JOIN goods g ON g.id = zt.goods_id
ORDER BY zt.dt DESC;
