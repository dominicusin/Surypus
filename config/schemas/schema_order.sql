-- ============================================================
-- Order Tables - Заказы
-- ============================================================

-- Orders (заказы)
CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    due_date DATE,
    op_kind_id BIGINT REFERENCES op_kind(id),
    otype SMALLINT NOT NULL,  -- 0=SUPPLIER, 1=CUSTOMER
    client_id BIGINT NOT NULL REFERENCES person(id),
    warehouse_id BIGINT REFERENCES location(id),
    contract_id BIGINT REFERENCES contract(id),
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=CONFIRMED, 2=INPROGRESS, 3=SHIPPED, 4=PARTIAL, 5=COMPLETED, 6=CANCELLED
    flags INTEGER DEFAULT 0,
    amount NUMERIC(18,4) DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0,
    vat NUMERIC(18,4) DEFAULT 0,
    total NUMERIC(18,4) DEFAULT 0,
    paid NUMERIC(18,4) DEFAULT 0,
    shipped NUMERIC(18,4) DEFAULT 0,
    memo TEXT,
    created_by BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code, otype)
);

-- Order lines (строки заказа)
CREATE TABLE IF NOT EXISTS order_line (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    qtty NUMERIC(18,6) NOT NULL,
    shipped_qtty NUMERIC(18,6) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) NOT NULL,
    discount NUMERIC(18,4) DEFAULT 0,
    vat_rate NUMERIC(5,4) DEFAULT 0.2,
    vat NUMERIC(18,4) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(order_id, line_no)
);

-- Order shipments (отгрузки по заказу)
CREATE TABLE IF NOT EXISTS order_shipment (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    bill_id BIGINT REFERENCES bill(id),  -- Документ отгрузки
    dt DATE NOT NULL,
    qtty NUMERIC(18,6) NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order payments (оплаты по заказу)
CREATE TABLE IF NOT EXISTS order_payment (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    payment_id BIGINT REFERENCES payment(id),
    dt DATE NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для заказов
CREATE INDEX IF NOT EXISTS idx_orders_code ON orders(code);
CREATE INDEX IF NOT EXISTS idx_orders_dt ON orders(dt);
CREATE INDEX IF NOT EXISTS idx_orders_client ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(otype);

CREATE INDEX IF NOT EXISTS idx_order_line_order ON order_line(order_id);
CREATE INDEX IF NOT EXISTS idx_order_line_goods ON order_line(goods_id);

CREATE INDEX IF NOT EXISTS idx_order_shipment_order ON order_shipment(order_id);
CREATE INDEX IF NOT EXISTS idx_order_payment_order ON order_payment(order_id);

-- ============================================================
-- Функции для работы с заказами
-- ============================================================

-- Расчёт суммы заказа
CREATE OR REPLACE FUNCTION order_calc_amount(p_order_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_amount NUMERIC(18,4);
    v_vat NUMERIC(18,4);
    v_total NUMERIC(18,4);
BEGIN
    SELECT 
        COALESCE(SUM(ol.qtty * ol.price - ol.discount), 0),
        COALESCE(SUM((ol.qtty * ol.price - ol.discount) * ol.vat_rate / (1 + ol.vat_rate)), 0)
    INTO v_amount, v_vat
    FROM order_line ol
    WHERE ol.order_id = p_order_id;
    
    v_total := v_amount + v_vat;
    
    UPDATE orders 
    SET amount = v_amount, vat = v_vat, total = v_total, updated_at = NOW()
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;

-- Триггер на обновление сумм
CREATE OR REPLACE FUNCTION order_line_amount_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM order_calc_amount(NEW.order_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_line_amount
    AFTER INSERT OR UPDATE OR DELETE ON order_line
    FOR EACH ROW EXECUTE FUNCTION order_line_amount_trigger();

-- Обновление статуса при отгрузке
CREATE OR REPLACE FUNCTION order_update_status_on_shipment(p_order_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_total_qtty NUMERIC(18,6);
    v_shipped_qtty NUMERIC(18,6);
BEGIN
    SELECT SUM(qtty), SUM(shipped_qtty)
    INTO v_total_qtty, v_shipped_qtty
    FROM order_line
    WHERE order_id = p_order_id;
    
    UPDATE orders
    SET status = CASE
        WHEN v_shipped_qtty >= v_total_qtty THEN 3  -- SHIPPED
        WHEN v_shipped_qtty > 0 THEN 4  -- PARTIAL
        ELSE status
    END,
    shipped = (SELECT SUM(shipped_qtty * price) FROM order_line WHERE order_id = p_order_id)
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Заказы поставщикам
CREATE OR REPLACE VIEW v_supplier_orders AS
SELECT 
    o.id, o.code, o.dt, o.due_date,
    p.id AS supplier_id, p.name AS supplier_name,
    o.amount, o.discount, o.vat, o.total,
    o.status, o.otype,
    (SELECT COUNT(*) FROM order_line WHERE order_id = o.id) AS line_count
FROM orders o
JOIN person p ON p.id = o.client_id
WHERE o.otype = 0
ORDER BY o.dt DESC;

-- Заказы клиентов
CREATE OR REPLACE VIEW v_customer_orders AS
SELECT 
    o.id, o.code, o.dt, o.due_date,
    p.id AS client_id, p.name AS client_name,
    o.amount, o.discount, o.vat, o.total,
    o.paid, o.shipped,
    o.status, o.otype,
    (SELECT COUNT(*) FROM order_line WHERE order_id = o.id) AS line_count
FROM orders o
JOIN person p ON p.id = o.client_id
WHERE o.otype = 1
ORDER BY o.dt DESC;

-- Просроченные заказы
CREATE OR REPLACE VIEW v_overdue_orders AS
SELECT 
    o.id, o.code, o.dt, o.due_date,
    p.id AS client_id, p.name AS client_name,
    o.total, o.status
FROM orders o
JOIN person p ON p.id = o.client_id
WHERE o.due_date < CURRENT_DATE 
    AND o.status NOT IN (5, 6)  -- NOT COMPLETED, NOT CANCELLED
ORDER BY o.due_date;

-- Выполнение заказов
CREATE OR REPLACE VIEW v_order_fulfillment AS
SELECT 
    o.id, o.code, o.dt, o.otype,
    p.name AS client_name,
    ol.goods_id, g.name AS goods_name,
    ol.qtty, ol.shipped_qtty,
    ol.qtty - ol.shipped_qtty AS remaining_qtty,
    CASE 
        WHEN ol.qtty = 0 THEN 0 
        ELSE (ol.shipped_qtty * 100.0 / ol.qtty) 
    END AS fulfillment_pct
FROM orders o
JOIN order_line ol ON ol.order_id = o.id
JOIN goods g ON g.id = ol.goods_id
JOIN person p ON p.id = o.client_id
WHERE ol.shipped_qtty < ol.qtty
    AND o.status NOT IN (5, 6)
ORDER BY o.dt, ol.line_no;
