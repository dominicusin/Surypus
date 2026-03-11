-- ============================================================
-- Receipt Tables - Поступления товаров
-- Соответствует C++ receipt.cpp
-- ============================================================

-- Receipt (главный документ поступления)
CREATE TABLE IF NOT EXISTS receipt_doc (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    op_kind_id BIGINT REFERENCES op_kind(id),
    supplier_id BIGINT NOT NULL REFERENCES person(id),  -- Поставщик
    warehouse_id BIGINT NOT NULL REFERENCES location(id),
    contract_id BIGINT REFERENCES contract(id),
    order_id BIGINT REFERENCES supp_order(id),          -- Заказ поставщику
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=PENDING, 2=PARTIAL, 3=COMPLETED, 4=CANCELLED
    flags INTEGER DEFAULT 0,
    amount NUMERIC(18,4) DEFAULT 0,   -- Сумма без НДС
    vat NUMERIC(18,4) DEFAULT 0,       -- НДС
    tax_period DATE,                   -- Налоговый период
    bill_id BIGINT REFERENCES bill(id), -- Связанный документ (счёт)
    invoice_no VARCHAR(32),            -- Номер счёта-фактуры
    invoice_dt DATE,                   -- Дата счёта-фактуры
    memo TEXT,
    created_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Receipt lines (строки поступления)
CREATE TABLE IF NOT EXISTS receipt_line (
    id BIGSERIAL PRIMARY KEY,
    receipt_id BIGINT NOT NULL REFERENCES receipt_doc(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    qtty NUMERIC(18,6) NOT NULL,
    price NUMERIC(18,4) NOT NULL,      -- Цена закупки
    cost NUMERIC(18,4) DEFAULT 0,      -- Себестоимость
    vat_rate NUMERIC(5,4) DEFAULT 0.2, -- Ставка НДС
    vat NUMERIC(18,4) DEFAULT 0,       -- Сумма НДС
    tax_grp_id BIGINT REFERENCES tax_grp(id),
    flags INTEGER DEFAULT 0,
    UNIQUE(receipt_id, line_no)
);

-- Receipt lots (партии, созданные при поступлении)
-- Соответствует ReceiptLot в C++
CREATE TABLE IF NOT EXISTS receipt_lot (
    id BIGSERIAL PRIMARY KEY,
    receipt_id BIGINT NOT NULL REFERENCES receipt_doc(id) ON DELETE CASCADE,
    line_id BIGINT REFERENCES receipt_line(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    bill_id BIGINT REFERENCES bill(id),   -- Документ поступления
    qtty NUMERIC(18,6) NOT NULL,
    rest NUMERIC(18,6) NOT NULL,          -- Остаток
    cost NUMERIC(18,4) NOT NULL,          -- Себестоимость
    price NUMERIC(18,4) NOT NULL,         -- Цена прихода
    expiry DATE,
    serial VARCHAR(64),
    country_id BIGINT REFERENCES country(id),
    gtd VARCHAR(32),                      -- ГТД (номер грузовой таможенной декларации)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для поступлений
CREATE INDEX IF NOT EXISTS idx_receipt_doc_code ON receipt_doc(code);
CREATE INDEX IF NOT EXISTS idx_receipt_doc_dt ON receipt_doc(dt);
CREATE INDEX IF NOT EXISTS idx_receipt_doc_supplier ON receipt_doc(supplier_id);
CREATE INDEX IF NOT EXISTS idx_receipt_doc_warehouse ON receipt_doc(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_receipt_doc_status ON receipt_doc(status);
CREATE INDEX IF NOT EXISTS idx_receipt_doc_order ON receipt_doc(order_id);

CREATE INDEX IF NOT EXISTS idx_receipt_line_receipt ON receipt_line(receipt_id);
CREATE INDEX IF NOT EXISTS idx_receipt_line_goods ON receipt_line(goods_id);

CREATE INDEX IF NOT EXISTS idx_receipt_lot_receipt ON receipt_lot(receipt_id);
CREATE INDEX IF NOT EXISTS idx_receipt_lot_lot ON receipt_lot(id);
CREATE INDEX IF NOT EXISTS idx_receipt_lot_goods ON receipt_lot(goods_id);
CREATE INDEX IF NOT EXISTS idx_receipt_lot_expiry ON receipt_lot(expiry);

-- ============================================================
-- Функции для работы с поступлениями
-- ============================================================

-- Автоматический расчёт суммы и НДС поступления
CREATE OR REPLACE FUNCTION receipt_calc_amount(p_receipt_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_amount NUMERIC(18,4);
    v_vat NUMERIC(18,4);
BEGIN
    SELECT 
        COALESCE(SUM(rl.qtty * rl.price), 0),
        COALESCE(SUM(rl.qtty * rl.price * rl.vat_rate / (1 + rl.vat_rate)), 0)
    INTO v_amount, v_vat
    FROM receipt_line rl
    WHERE rl.receipt_id = p_receipt_id;
    
    UPDATE receipt_doc 
    SET amount = v_amount, vat = v_vat, updated_at = NOW()
    WHERE id = p_receipt_id;
END;
$$ LANGUAGE plpgsql;

-- Триггер на обновление сумм при изменении строк
CREATE OR REPLACE FUNCTION receipt_line_amount_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM receipt_calc_amount(NEW.receipt_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_receipt_line_amount
    AFTER INSERT OR UPDATE OR DELETE ON receipt_line
    FOR EACH ROW EXECUTE FUNCTION receipt_line_amount_trigger();

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Просмотр поступлений за период
CREATE OR REPLACE VIEW v_receipts_by_period AS
SELECT 
    rd.id,
    rd.code,
    rd.dt,
    p.name AS supplier_name,
    l.name AS warehouse_name,
    rd.amount,
    rd.vat,
    rd.amount + rd.vat AS total,
    rd.status,
    rd.invoice_no,
    rd.invoice_dt
FROM receipt_doc rd
JOIN person p ON p.id = rd.supplier_id
JOIN location l ON l.id = rd.warehouse_id
ORDER BY rd.dt DESC;

-- Просмотр содержимого поступления
CREATE OR REPLACE VIEW v_receipt_contents AS
SELECT 
    rd.id AS receipt_id,
    rd.code,
    rd.dt,
    rl.line_no,
    g.id AS goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    rl.qtty,
    u.name AS unit_name,
    rl.price,
    rl.qtty * rl.price AS line_amount,
    rl.vat_rate,
    rl.vat
FROM receipt_doc rd
JOIN receipt_line rl ON rl.receipt_id = rd.id
JOIN goods g ON g.id = rl.goods_id
LEFT JOIN unit u ON u.id = rl.unit_id
ORDER BY rd.dt, rl.line_no;

-- Просмотр партий поступления
CREATE OR REPLACE VIEW v_receipt_lots AS
SELECT 
    rl.id AS lot_id,
    rl.goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    rl.qtty,
    rl.rest,
    rl.cost,
    rl.price,
    rl.expiry,
    rl.serial,
    rl.gtd,
    rd.code AS receipt_code,
    rd.dt AS receipt_dt
FROM receipt_lot rl
JOIN receipt_doc rd ON rd.id = rl.receipt_id
JOIN goods g ON g.id = rl.goods_id
WHERE rl.rest > 0
ORDER BY rd.dt, rl.id;
