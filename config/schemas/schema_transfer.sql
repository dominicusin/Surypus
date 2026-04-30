-- ============================================================
-- Transfer Tables - Перемещения товаров
-- Соответствует C++ transfer.cpp
-- ============================================================

-- Transfer (главный документ перемещения)
CREATE TABLE IF NOT EXISTS transfer_doc (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    op_kind_id BIGINT REFERENCES op_kind(id),
    src_loc_id BIGINT NOT NULL REFERENCES location(id),
    dst_loc_id BIGINT NOT NULL REFERENCES location(id),
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=PENDING, 2=INTRANSIT, 3=COMPLETED, 4=CANCELLED
    flags INTEGER DEFAULT 0,
    shipped_dt DATE,
    received_dt DATE,
    waybill_no VARCHAR(64),
    ship_doc_no VARCHAR(64),   -- Номер транспортной накладной
    ship_person_id BIGINT,     -- Перевозчик (Person)
    vehicle_id BIGINT,         -- Транспорт
    driver_id BIGINT,          -- Водитель
    amount NUMERIC(18,4) DEFAULT 0,
    cost NUMERIC(18,4) DEFAULT 0,
    memo TEXT,
    created_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Transfer lines (строки перемещения)
CREATE TABLE IF NOT EXISTS transfer_line (
    id BIGSERIAL PRIMARY KEY,
    transfer_id BIGINT NOT NULL REFERENCES transfer_doc(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    qtty NUMERIC(18,6) NOT NULL,
    price NUMERIC(18,4) DEFAULT 0,
    cost NUMERIC(18,4) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(transfer_id, line_no)
);

-- Transfer lots (партии в перемещении)
-- Соответствует TransferLot в C++
CREATE TABLE IF NOT EXISTS transfer_lot (
    id BIGSERIAL PRIMARY KEY,
    transfer_id BIGINT NOT NULL REFERENCES transfer_doc(id) ON DELETE CASCADE,
    line_id BIGINT REFERENCES transfer_line(id),
    direction SMALLINT NOT NULL,  -- 0=исходящий (отгрузка), 1=входящий (приход)
    lot_id BIGINT REFERENCES lot(id),     -- Ссылка на партию
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    bill_id BIGINT REFERENCES bill(id),   -- Документ прихода партии
    qtty NUMERIC(18,6) NOT NULL,
    rest NUMERIC(18,6) NOT NULL,           -- Остаток для списания
    cost NUMERIC(18,4) DEFAULT 0,
    expiry DATE,
    serial VARCHAR(64),                    -- Серийный номер
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для перемещений
CREATE INDEX IF NOT EXISTS idx_transfer_doc_code ON transfer_doc(code);
CREATE INDEX IF NOT EXISTS idx_transfer_doc_dt ON transfer_doc(dt);
CREATE INDEX IF NOT EXISTS idx_transfer_doc_src ON transfer_doc(src_loc_id);
CREATE INDEX IF NOT EXISTS idx_transfer_doc_dst ON transfer_doc(dst_loc_id);
CREATE INDEX IF NOT EXISTS idx_transfer_doc_status ON transfer_doc(status);

CREATE INDEX IF NOT EXISTS idx_transfer_line_transfer ON transfer_line(transfer_id);
CREATE INDEX IF NOT EXISTS idx_transfer_line_goods ON transfer_line(goods_id);

CREATE INDEX IF NOT EXISTS idx_transfer_lot_transfer ON transfer_lot(transfer_id);
CREATE INDEX IF NOT EXISTS idx_transfer_lot_lot ON transfer_lot(lot_id);
CREATE INDEX IF NOT EXISTS idx_transfer_lot_goods ON transfer_lot(goods_id);

-- ============================================================
-- Функции для работы с перемещениями
-- ============================================================

-- Автоматический расчёт суммы перемещения
CREATE OR REPLACE FUNCTION transfer_calc_amount(p_transfer_id BIGINT)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_amount NUMERIC(18,4);
BEGIN
    SELECT COALESCE(SUM(tl.qtty * tl.price), 0)
    INTO v_amount
    FROM transfer_line tl
    WHERE tl.transfer_id = p_transfer_id;
    
    UPDATE transfer_doc 
    SET amount = v_amount, updated_at = NOW()
    WHERE id = p_transfer_id;
    
    RETURN v_amount;
END;
$$ LANGUAGE plpgsql;

-- Триггер на обновление суммы при изменении строк
CREATE OR REPLACE FUNCTION transfer_line_amount_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM transfer_calc_amount(NEW.transfer_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transfer_line_amount
    AFTER INSERT OR UPDATE OR DELETE ON transfer_line
    FOR EACH ROW EXECUTE FUNCTION transfer_line_amount_trigger();

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Перемещения в пути
CREATE OR REPLACE VIEW v_transfers_in_transit AS
SELECT 
    td.id,
    td.code,
    td.dt,
    td.src_loc_id,
    l_src.name AS src_loc_name,
    td.dst_loc_id,
    l_dst.name AS dst_loc_name,
    td.amount,
    td.status,
    td.shipped_dt,
    EXTRACT(DAYS FROM CURRENT_DATE - td.shipped_dt) AS days_in_transit
FROM transfer_doc td
JOIN location l_src ON l_src.id = td.src_loc_id
JOIN location l_dst ON l_dst.id = td.dst_loc_id
WHERE td.status = 2  -- INTRANSIT
ORDER BY td.shipped_dt;

-- Просмотр содержимого перемещения
CREATE OR REPLACE VIEW v_transfer_contents AS
SELECT 
    td.id AS transfer_id,
    td.code,
    td.dt,
    tl.line_no,
    g.id AS goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    tl.qtty,
    u.name AS unit_name,
    tl.price,
    tl.qtty * tl.price AS line_amount
FROM transfer_doc td
JOIN transfer_line tl ON tl.transfer_id = td.id
JOIN goods g ON g.id = tl.goods_id
LEFT JOIN unit u ON u.id = tl.unit_id
ORDER BY td.dt, tl.line_no;
