-- ============================================================================
-- SCHEMA: Marketplace Integration (Интеграция с маркетплейсами)
-- Соответствует C++ классам PPMarketplaceInterface в marketplace.cpp
-- ============================================================================

-- Таблица маркетплейсов
CREATE TABLE IF NOT EXISTS marketplace (
    id              SERIAL PRIMARY KEY,
    code            VARCHAR(50) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    marketplace_type VARCHAR(50) NOT NULL,  -- WILDBERRIES, OZON, YANDEX, SBERMEGA, LAMODA, CUSTOM
    api_endpoint    VARCHAR(500),
    client_id       VARCHAR(255),
    api_key_hash    VARCHAR(255),
    secret_key_hash VARCHAR(255),
    enabled         BOOLEAN DEFAULT TRUE,
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mp_code_unique UNIQUE (code),
    CONSTRAINT mp_type_check CHECK (marketplace_type IN ('WILDBERRIES', 'OZON', 'YANDEX', 'SBERMEGA', 'LAMODA', 'CUSTOM'))
);

-- Таблица товаров маркетплейсов
CREATE TABLE IF NOT EXISTS marketplace_goods (
    id              SERIAL PRIMARY KEY,
    marketplace_id  INTEGER NOT NULL REFERENCES marketplace(id) ON DELETE CASCADE,
    marketplace_sku VARCHAR(100) NOT NULL,
    local_goods_id  INTEGER NOT NULL,
    price           DECIMAL(18,6),
    old_price       DECIMAL(18,6),
    stock_total     DECIMAL(18,6) DEFAULT 0,
    stock_reserved  DECIMAL(18,6) DEFAULT 0,
    flags           INTEGER DEFAULT 0,
    last_sync       TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mg_marketplace_sku_unique UNIQUE (marketplace_id, marketplace_sku),
    CONSTRAINT mg_stock_check CHECK (stock_total >= 0 AND stock_reserved >= 0),
    CONSTRAINT mg_price_check CHECK (price IS NULL OR price >= 0),
    CONSTRAINT mg_available_stock CHECK (stock_total >= stock_reserved)
);

-- Таблица заказов с маркетплейсов
CREATE TABLE IF NOT EXISTS marketplace_order (
    id              SERIAL PRIMARY KEY,
    marketplace_id  INTEGER NOT NULL REFERENCES marketplace(id),
    external_id     VARCHAR(100) NOT NULL,
    order_date      DATE NOT NULL,
    status          VARCHAR(30) DEFAULT 'NEW',  -- NEW, PROCESSING, ASSEMBLED, SHIPPED, DELIVERED, CANCELLED, RETURNED
    total           DECIMAL(18,6) NOT NULL,
    commission      DECIMAL(18,6) DEFAULT 0,
    logistics_cost  DECIMAL(18,6) DEFAULT 0,
    local_bill_id   INTEGER,              -- Ссылка на локальный документ
    raw_data        JSONB,
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mo_marketplace_external_unique UNIQUE (marketplace_id, external_id),
    CONSTRAINT mo_status_check CHECK (status IN ('NEW', 'PROCESSING', 'ASSEMBLED', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED')),
    CONSTRAINT mo_total_check CHECK (total >= 0),
    CONSTRAINT mo_commission_check CHECK (commission >= 0)
);

-- Таблица строк заказов маркетплейсов
CREATE TABLE IF NOT EXISTS marketplace_order_line (
    id              SERIAL PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES marketplace_order(id) ON DELETE CASCADE,
    line_no         INTEGER NOT NULL,
    marketplace_sku VARCHAR(100),
    goods_id        INTEGER NOT NULL,
    goods_name      VARCHAR(255),
    quantity        DECIMAL(18,6) NOT NULL,
    price           DECIMAL(18,6) NOT NULL,
    discount        DECIMAL(18,6) DEFAULT 0,
    
    CONSTRAINT mol_order_fk FOREIGN KEY (order_id) REFERENCES marketplace_order(id),
    CONSTRAINT mol_quantity_check CHECK (quantity > 0),
    CONSTRAINT mol_price_check CHECK (price >= 0),
    CONSTRAINT mol_line_unique UNIQUE (order_id, line_no)
);

-- Таблица отчётов маркетплейсов
CREATE TABLE IF NOT EXISTS marketplace_report (
    id              SERIAL PRIMARY KEY,
    marketplace_id  INTEGER NOT NULL REFERENCES marketplace(id),
    report_date     DATE NOT NULL,
    period_start    DATE NOT NULL,
    period_end      DATE NOT NULL,
    revenue         DECIMAL(18,6) DEFAULT 0,
    commission      DECIMAL(18,6) DEFAULT 0,
    logistics       DECIMAL(18,6) DEFAULT 0,
    returns         DECIMAL(18,6) DEFAULT 0,
    net_amount      DECIMAL(18,6),
    raw_data        JSONB,
    status          VARCHAR(20) DEFAULT 'PENDING',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mr_marketplace_date_unique UNIQUE (marketplace_id, report_date),
    CONSTRAINT mr_period_check CHECK (period_start <= period_end),
    CONSTRAINT mr_revenue_check CHECK (revenue >= 0),
    CONSTRAINT mr_commission_check CHECK (commission >= 0),
    CONSTRAINT mr_net_check CHECK (net_amount IS NULL OR net_amount >= -revenue)
);

-- Таблица остатков на маркетплейсах
CREATE TABLE IF NOT EXISTS marketplace_stock (
    id              SERIAL PRIMARY KEY,
    goods_id        INTEGER NOT NULL,
    marketplace_id  INTEGER NOT NULL REFERENCES marketplace(id),
    warehouse_id    VARCHAR(50),
    stock           DECIMAL(18,6) DEFAULT 0,
    reserved        DECIMAL(18,6) DEFAULT 0,
    last_update     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ms_goods_marketplace_unique UNIQUE (goods_id, marketplace_id, warehouse_id),
    CONSTRAINT ms_stock_check CHECK (stock >= 0 AND reserved >= 0 AND stock >= reserved)
);

-- Таблица цен маркетплейсов
CREATE TABLE IF NOT EXISTS marketplace_price (
    id              SERIAL PRIMARY KEY,
    goods_id        INTEGER NOT NULL,
    marketplace_id  INTEGER NOT NULL REFERENCES marketplace(id),
    price           DECIMAL(18,6) NOT NULL,
    discount_price  DECIMAL(18,6),
    vat_included    BOOLEAN DEFAULT TRUE,
    start_date      DATE,
    end_date        DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT mp_goods_marketplace_unique UNIQUE (goods_id, marketplace_id, start_date),
    CONSTRAINT mp_price_check CHECK (price > 0)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_mg_marketplace ON marketplace_goods(marketplace_id);
CREATE INDEX IF NOT EXISTS idx_mg_goods ON marketplace_goods(local_goods_id);
CREATE INDEX IF NOT EXISTS idx_mo_marketplace ON marketplace_order(marketplace_id);
CREATE INDEX IF NOT EXISTS idx_mo_status ON marketplace_order(status);
CREATE INDEX IF NOT EXISTS idx_mo_date ON marketplace_order(order_date DESC);
CREATE INDEX IF NOT EXISTS idx_mol_order ON marketplace_order_line(order_id);
CREATE INDEX IF NOT EXISTS idx_mr_marketplace ON marketplace_report(marketplace_id, report_date DESC);
CREATE INDEX IF NOT EXISTS idx_ms_goods ON marketplace_stock(goods_id);

-- Функция: Рассчитать комиссию
CREATE OR REPLACE FUNCTION calculate_marketplace_commission(
    p_total DECIMAL,
    p_commission_rate DECIMAL
)
RETURNS DECIMAL(18,6) AS $$
BEGIN
    RETURN p_total * (p_commission_rate / 100);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать доступный остаток
CREATE OR REPLACE FUNCTION calculate_available_stock(p_goods_id INTEGER, p_marketplace_id INTEGER)
RETURNS DECIMAL(18,6) AS $$
DECLARE
    v_total DECIMAL(18,6);
    v_reserved DECIMAL(18,6);
BEGIN
    SELECT COALESCE(stock, 0), COALESCE(reserved, 0)
    INTO v_total, v_reserved
    FROM marketplace_stock
    WHERE goods_id = p_goods_id AND marketplace_id = p_marketplace_id;
    
    RETURN v_total - v_reserved;
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать чистую сумму отчёта
CREATE OR REPLACE FUNCTION calculate_marketplace_net(p_report_id INTEGER)
RETURNS DECIMAL(18,6) AS $$
DECLARE
    v_revenue DECIMAL(18,6);
    v_commission DECIMAL(18,6);
    v_logistics DECIMAL(18,6);
    v_returns DECIMAL(18,6);
BEGIN
    SELECT revenue, commission, logistics, returns
    INTO v_revenue, v_commission, v_logistics, v_returns
    FROM marketplace_report
    WHERE id = p_report_id;
    
    RETURN v_revenue - v_commission - v_logistics - v_returns;
END;
$$ LANGUAGE plpgsql;

-- Процедура: Синхронизировать остатки
CREATE OR REPLACE PROCEDURE sync_marketplace_stock(
    p_goods_id INTEGER,
    p_marketplace_id INTEGER,
    p_stock DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO marketplace_stock (goods_id, marketplace_id, stock, last_update)
    VALUES (p_goods_id, p_marketplace_id, p_stock, CURRENT_TIMESTAMP)
    ON CONFLICT (goods_id, marketplace_id)
      DO UPDATE SET stock = p_stock, last_update = CURRENT_TIMESTAMP;
    
    RAISE NOTICE 'Stock synced for goods % on marketplace %', p_goods_id, p_marketplace_id;
END;
$$;

-- Процедура: Обновить цены
CREATE OR REPLACE PROCEDURE update_marketplace_price(
    p_goods_id INTEGER,
    p_marketplace_id INTEGER,
    p_price DECIMAL,
    p_old_price DECIMAL DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE marketplace_goods
    SET price = p_price,
        old_price = COALESCE(p_old_price, old_price),
        last_sync = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE local_goods_id = p_goods_id AND marketplace_id = p_marketplace_id;
    
    -- Обновить историю цен
    INSERT INTO marketplace_price (goods_id, marketplace_id, price)
    VALUES (p_goods_id, p_marketplace_id, p_price)
    ON CONFLICT (goods_id, marketplace_id, start_date) DO NOTHING;
    
    RAISE NOTICE 'Price updated for goods % on marketplace %', p_goods_id, p_marketplace_id;
END;
$$;

-- Процедура: Обработать заказ
CREATE OR REPLACE PROCEDURE process_marketplace_order(
    p_order_id INTEGER,
    p_new_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE marketplace_order
    SET status = p_new_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_order_id;
    
    -- Если заказ отменён, освободить резервы
    IF p_new_status = 'CANCELLED' THEN
        UPDATE marketplace_stock ms
        SET reserved = GREATEST(0, reserved - (
            SELECT COALESCE(SUM(mol.quantity), 0)
            FROM marketplace_order_line mol
            JOIN marketplace_order mo ON mo.id = mol.order_id
            WHERE mo.id = p_order_id
        ))
        FROM marketplace_order mo
        JOIN marketplace_order_line mol ON mol.order_id = mo.id
        WHERE mo.id = p_order_id AND ms.goods_id = mol.goods_id;
    END IF;
    
    RAISE NOTICE 'Order % status changed to %', p_order_id, p_new_status;
END;
$$;

-- Представление: Активные заказы
CREATE TABLE IF NOT EXISTS v_marketplace_active_orders AS
SELECT 
    mo.id,
    mo.external_id,
    m.name AS marketplace_name,
    mo.order_date,
    mo.status,
    mo.total,
    mo.commission,
    COUNT(mol.id) AS line_count
FROM marketplace_order mo
JOIN marketplace m ON m.id = mo.marketplace_id
LEFT JOIN marketplace_order_line mol ON mol.order_id = mo.id
WHERE mo.status IN ('NEW', 'PROCESSING', 'ASSEMBLED', 'SHIPPED')
GROUP BY mo.id, mo.external_id, m.name, mo.order_date, mo.status, mo.total, mo.commission
ORDER BY mo.order_date DESC;

-- Представление: Остатки товаров по маркетплейсам
CREATE OR REPLACE VIEW v_marketplace_stock AS
SELECT 
    mg.local_goods_id,
    g.name AS goods_name,
    m.name AS marketplace_name,
    ms.stock AS total_stock,
    ms.reserved,
    ms.stock - ms.reserved AS available_stock,
    ms.last_update
FROM marketplace_stock ms
JOIN marketplace_goods mg ON mg.marketplace_id = ms.marketplace_id 
    AND mg.local_goods_id = ms.goods_id
JOIN marketplace m ON m.id = ms.marketplace_id
LEFT JOIN goods g ON g.id = mg.local_goods_id
WHERE m.enabled = TRUE;

-- Представление: Финансы маркетплейсов
CREATE OR REPLACE VIEW v_marketplace_finance AS
SELECT 
    mr.marketplace_id,
    m.name AS marketplace_name,
    mr.period_start,
    mr.period_end,
    mr.revenue,
    mr.commission,
    mr.logistics,
    mr.returns,
    mr.net_amount,
    CASE 
        WHEN mr.revenue > 0 THEN (mr.commission / mr.revenue) * 100 
        ELSE 0 
    END AS commission_pct
FROM marketplace_report mr
JOIN marketplace m ON m.id = mr.marketplace_id
ORDER BY mr.period_end DESC;

-- Представление: Топ товаров по продажам
CREATE OR REPLACE VIEW v_marketplace_top_goods AS
SELECT 
    mg.local_goods_id,
    g.name AS goods_name,
    mp.marketplace_id,
    m.name AS marketplace_name,
    SUM(mol.quantity) AS total_sold,
    SUM(mol.quantity * mol.price) AS total_revenue,
    COUNT(DISTINCT mo.id) AS order_count
FROM marketplace_order_line mol
JOIN marketplace_order mo ON mo.id = mol.order_id
JOIN marketplace_goods mg ON mg.marketplace_id = mo.marketplace_id 
    AND mg.marketplace_sku = mol.marketplace_sku
JOIN marketplace m ON m.id = mo.marketplace_id
LEFT JOIN goods g ON g.id = mg.local_goods_id
CROSS JOIN LATERAL (
    SELECT id FROM marketplace LIMIT 1
) mp
WHERE mo.status IN ('DELIVERED', 'SHIPPED')
GROUP BY mg.local_goods_id, g.name, mp.marketplace_id, m.name
ORDER BY total_revenue DESC;

-- Триггер: Обновить updated_at
CREATE OR REPLACE FUNCTION update_marketplace_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_marketplace_updated
    BEFORE UPDATE ON marketplace
    FOR EACH ROW
    EXECUTE FUNCTION update_marketplace_timestamp();
