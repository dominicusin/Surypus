-- ============================================================
-- Goods Tables - Товары
-- ============================================================

-- Основная таблица товаров
CREATE TABLE IF NOT EXISTS goods (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    full_name VARCHAR(512),
    abbr VARCHAR(64),
    unit_id BIGINT NOT NULL REFERENCES unit(id),
    parent_id BIGINT REFERENCES goods(id),
    gtype SMALLINT NOT NULL DEFAULT 0,  -- 0=GOODS, 1=SERVICE, 2=PRODUCT, 3=ASSET, 4=CONTAINER, 5=PACK
    brand_id BIGINT REFERENCES brand(id),
    category_id BIGINT REFERENCES category(id),
    taxcat_id BIGINT,
    barcode VARCHAR(32),
    ar_code VARCHAR(64),                -- Код у контрагента
    pharm_code VARCHAR(32),             -- Фармацевтический код
    mnf_id BIGINT,                      -- Производитель
    country_id BIGINT REFERENCES country(id),
    manuf_date DATE,
    expiry_days INT,                    -- Срок годности в днях
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Расширенные свойства товара
CREATE TABLE IF NOT EXISTS goods_ext (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price DECIMAL(18,4) DEFAULT 0,
    cost DECIMAL(18,4) DEFAULT 0,
    restrict_price BOOLEAN DEFAULT FALSE,
    min_price DECIMAL(18,4) DEFAULT 0,
    max_price DECIMAL(18,4),
    tax_flags INTEGER DEFAULT 0,
    vat_rate DECIMAL(5,2) DEFAULT 0,
    excise DECIMAL(18,4) DEFAULT 0,
    marking_type SMALLINT,              -- 0=NONE, 1=EGAIS, 2=CHEST, 3=MORION, 4=DATAMATRIX
    gtin VARCHAR(14),
    min_order_qty DECIMAL(18,4) DEFAULT 0,
    pack_qty DECIMAL(18,4) DEFAULT 1,
    weight DECIMAL(18,4) DEFAULT 0,
    volume DECIMAL(18,4) DEFAULT 0,
    length DECIMAL(18,4) DEFAULT 0,
    width DECIMAL(18,4) DEFAULT 0,
    height DECIMAL(18,4) DEFAULT 0,
    UNIQUE(goods_id)
);

-- Остатки товаров
CREATE TABLE IF NOT EXISTS stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    location_id BIGINT NOT NULL REFERENCES location(id),
    lot_id BIGINT REFERENCES lot(id),
    quantity DECIMAL(18,4) DEFAULT 0,
    reserved_qty DECIMAL(18,4) DEFAULT 0,
    cost DECIMAL(18,4) DEFAULT 0,
    price DECIMAL(18,4) DEFAULT 0,
    expiry_date DATE,
    serial_number VARCHAR(64),
    UNIQUE(goods_id, location_id, lot_id)
);

-- Партии товаров
CREATE TABLE IF NOT EXISTS lot (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL REFERENCES location(id),
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    dt DATE NOT NULL,
    exp_dt DATE,
    rest DECIMAL(18,4) DEFAULT 0,
    cost DECIMAL(18,4) DEFAULT 0,
    price DECIMAL(18,4) DEFAULT 0,
    serial VARCHAR(64),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Группы товаров (иерархия)
CREATE TABLE IF NOT EXISTS goodsgroup (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goodsgroup(id),
    tree_flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Классификаторы товаров
CREATE TABLE IF NOT EXISTS goodsclass (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goodsclass(id),
    dims JSONB,                         -- Измерения классификации
    UNIQUE(code)
);

-- Связи товаров
CREATE TABLE IF NOT EXISTS goodsassoc (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    assoc_type SMALLINT NOT NULL,       -- 0=ANALOG, 1=SUBS, 2=SUPER
    linked_goods_id BIGINT NOT NULL REFERENCES goods(id),
    UNIQUE(goods_id, assoc_type, linked_goods_id)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_goods_parent ON goods(parent_id);
CREATE INDEX IF NOT EXISTS idx_goods_barcode ON goods(barcode);
CREATE INDEX IF NOT EXISTS idx_goods_brand ON goods(brand_id);
CREATE INDEX IF NOT EXISTS idx_goods_category ON goods(category_id);
CREATE INDEX IF NOT EXISTS idx_goods_ext_price ON goods_ext(price);
CREATE INDEX IF NOT EXISTS idx_stock_goods ON stock(goods_id);
CREATE INDEX IF NOT EXISTS idx_stock_location ON stock(location_id);
CREATE INDEX IF NOT EXISTS idx_lot_goods ON lot(goods_id);
CREATE INDEX IF NOT EXISTS idx_lot_expiry ON lot(exp_dt);
CREATE INDEX IF NOT EXISTS idx_goodsgroup_parent ON goodsgroup(parent_id);
