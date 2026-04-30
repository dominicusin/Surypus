-- ============================================================
-- Pricing Tables - Ценообразование
-- ============================================================

-- Price lists (прайс-листы)
CREATE TABLE IF NOT EXISTS price_list (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    name VARCHAR(256) NOT NULL,
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=ACTIVE, 2=ARCHIVED, 3=CANCELLED
    flags INTEGER DEFAULT 0,
    valid_from DATE NOT NULL,
    valid_to DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number)
);

-- Price items (цены товаров)
CREATE TABLE IF NOT EXISTS price_item (
    id BIGSERIAL PRIMARY KEY,
    price_list_id BIGINT NOT NULL REFERENCES price_list(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price NUMERIC(18,4) NOT NULL,
    min_quantity NUMERIC(18,6) DEFAULT 1,
    max_quantity NUMERIC(18,6),
    discount NUMERIC(5,2) DEFAULT 0,  -- Процент скидки
    vat_rate NUMERIC(5,2) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(price_list_id, goods_id, min_quantity)
);

-- Price types (типы цен)
CREATE TABLE IF NOT EXISTS price_type (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    code VARCHAR(16) NOT NULL,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Goods price (текущие цены товаров)
CREATE TABLE IF NOT EXISTS goods_price (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price_type_id BIGINT NOT NULL REFERENCES price_type(id),
    price NUMERIC(18,4) NOT NULL,
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    location_id BIGINT REFERENCES location(id),  -- Цена для склада
    person_id BIGINT REFERENCES person(id),      -- Цена для контрагента
    valid_from DATE NOT NULL,
    valid_to DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для цен
CREATE INDEX IF NOT EXISTS idx_price_list_number ON price_list(number);
CREATE INDEX IF NOT EXISTS idx_price_list_status ON price_list(status);
CREATE INDEX IF NOT EXISTS idx_price_list_dates ON price_list(valid_from, valid_to);

CREATE INDEX IF NOT EXISTS idx_price_item_list ON price_item(price_list_id);
CREATE INDEX IF NOT EXISTS idx_price_item_goods ON price_item(goods_id);

CREATE INDEX IF NOT EXISTS idx_goods_price_goods ON goods_price(goods_id);
CREATE INDEX IF NOT EXISTS idx_goods_price_type ON goods_price(price_type_id);
CREATE INDEX IF NOT EXISTS idx_goods_price_location ON goods_price(location_id);

-- ============================================================
-- Функции для цен
-- ============================================================

-- Получить цену товара на дату
CREATE OR REPLACE FUNCTION get_goods_price(
    p_goods_id BIGINT,
    p_price_type_id BIGINT,
    p_date DATE DEFAULT CURRENT_DATE
) RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_price NUMERIC(18,4);
BEGIN
    SELECT gp.price INTO v_price
    FROM goods_price gp
    WHERE gp.goods_id = p_goods_id
        AND gp.price_type_id = p_price_type_id
        AND gp.valid_from <= p_date
        AND (gp.valid_to IS NULL OR gp.valid_to >= p_date)
    ORDER BY gp.valid_from DESC
    LIMIT 1;
    
    RETURN COALESCE(v_price, 0);
END;
$$ LANGUAGE plpgsql;

-- Получить цену из прайс-листа
CREATE OR REPLACE FUNCTION get_price_from_list(
    p_price_list_id BIGINT,
    p_goods_id BIGINT,
    p_quantity NUMERIC(18,6) DEFAULT 1
) RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_price NUMERIC(18,4);
    v_discount NUMERIC(5,2);
BEGIN
    SELECT pi.price, pi.discount INTO v_price, v_discount
    FROM price_item pi
    WHERE pi.price_list_id = p_price_list_id
        AND pi.goods_id = p_goods_id
        AND (pi.min_quantity IS NULL OR pi.min_quantity <= p_quantity)
        AND (pi.max_quantity IS NULL OR pi.max_quantity >= p_quantity)
    ORDER BY pi.min_quantity DESC
    LIMIT 1;
    
    IF v_price IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Применить скидку
    RETURN v_price * (1 - COALESCE(v_discount, 0) / 100);
END;
$$ LANGUAGE plpgsql;

-- Активировать прайс-лист
CREATE OR REPLACE FUNCTION activate_price_list(p_list_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE price_list SET status = 1 WHERE id = p_list_id AND status = 0;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Обновить текущие цены из прайс-листа
CREATE OR REPLACE FUNCTION sync_prices_from_list(
    p_price_list_id BIGINT,
    p_price_type_id BIGINT
) RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_price NUMERIC(18,4);
    v_discount NUMERIC(5,2);
BEGIN
    FOR v_price, v_discount IN
        SELECT pi.price, pi.discount FROM price_item pi WHERE pi.price_list_id = p_price_list_id
    LOOP
        INSERT INTO goods_price (goods_id, price_type_id, price, currency_id, valid_from)
        VALUES (
            (SELECT pi2.goods_id FROM price_item pi2 WHERE pi2.price_list_id = p_price_list_id AND pi2.price = v_price AND pi2.discount = v_discount LIMIT 1),
            p_price_type_id,
            v_price * (1 - v_discount / 100),
            (SELECT pl.currency_id FROM price_list pl WHERE pl.id = p_price_list_id),
            CURRENT_DATE
        )
        ON CONFLICT (goods_id, price_type_id, valid_from) 
        DO UPDATE SET price = EXCLUDED.price;
        
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Активные прайс-листы
CREATE OR REPLACE VIEW v_active_price_lists AS
SELECT 
    pl.id, pl.number, pl.dt, pl.name, pl.valid_from, pl.valid_to,
    c.code AS currency_code,
    COUNT(pi.id) AS item_count
FROM price_list pl
JOIN currency c ON c.id = pl.currency_id
LEFT JOIN price_item pi ON pi.price_list_id = pl.id
WHERE pl.status = 1  -- ACTIVE
GROUP BY pl.id, pl.number, pl.dt, pl.name, pl.valid_from, pl.valid_to, c.code
ORDER BY pl.valid_from DESC;

-- Текущие цены товаров
CREATE OR REPLACE VIEW v_current_prices AS
SELECT 
    gp.id, gp.goods_id, g.name AS goods_name,
    gp.price_type_id, pt.name AS price_type_name,
    gp.price, gp.currency_id, c.code AS currency_code,
    gp.location_id, l.name AS location_name,
    gp.valid_from
FROM goods_price gp
JOIN goods g ON g.id = gp.goods_id
JOIN price_type pt ON pt.id = gp.price_type_id
JOIN currency c ON c.id = gp.currency_id
LEFT JOIN location l ON l.id = gp.location_id
WHERE gp.valid_from <= CURRENT_DATE 
    AND (gp.valid_to IS NULL OR gp.valid_to >= CURRENT_DATE)
ORDER BY g.name, pt.name;

-- Цены по типам
CREATE OR REPLACE VIEW v_prices_by_type AS
SELECT 
    g.id AS goods_id, g.name AS goods_name,
    pt.id AS price_type_id, pt.name AS price_type_name,
    gp.price
FROM goods g
CROSS JOIN price_type pt
LEFT JOIN goods_price gp ON gp.goods_id = g.id 
    AND gp.price_type_id = pt.id
    AND gp.valid_from <= CURRENT_DATE 
    AND (gp.valid_to IS NULL OR gp.valid_to >= CURRENT_DATE)
ORDER BY g.name, pt.name;
