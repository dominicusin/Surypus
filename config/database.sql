-- Surypus Database Initialization Script
-- PostgreSQL version
-- Replaces Btrieve with PostgreSQL

-- Create database
-- CREATE DATABASE surypus;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create goods table
CREATE TABLE IF NOT EXISTS goods (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goods(id),
    kind SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    brand_id BIGINT,
    manuf_id BIGINT,
    tax_grp_id BIGINT,
    unit_id BIGINT,
    ph_unit_id BIGINT,
    struc_id BIGINT,
    gds_cls_id BIGINT,
    goods_type_id BIGINT,
    code VARCHAR(16),
    ph_code VARCHAR(16),
    barcode TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_goods_parent ON goods(parent_id);
CREATE INDEX IF NOT EXISTS idx_goods_kind ON goods(kind);
CREATE INDEX IF NOT EXISTS idx_goods_code ON goods(code);
CREATE INDEX IF NOT EXISTS idx_goods_name ON goods USING gin(name gin_trgm_ops);

-- Create person table
CREATE TABLE IF NOT EXISTS person (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS person_kind (
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    kind_id BIGINT NOT NULL,
    name VARCHAR(256),
    PRIMARY KEY (person_id, kind_id)
);

CREATE INDEX IF NOT EXISTS idx_person_name ON person USING gin(name gin_trgm_ops);

-- Create location table
CREATE TABLE IF NOT EXISTS location (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    parent_id BIGINT REFERENCES location(id),
    address TEXT,
    phone TEXT,
    email TEXT,
    coord_x DOUBLE PRECISION,
    coord_y DOUBLE PRECISION,
    main_org_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_location_parent ON location(parent_id);
CREATE INDEX IF NOT EXISTS idx_location_type ON location(type);

-- Create bill table
CREATE TABLE IF NOT EXISTS bill (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    dt DATE NOT NULL,
    op_id BIGINT NOT NULL,
    object_id BIGINT,
    object2_id BIGINT,
    loc_id BIGINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT NOT NULL DEFAULT 0,
    c_rate NUMERIC(18,9) NOT NULL DEFAULT 1,
    flags INTEGER DEFAULT 0,
    status_id BIGINT,
    link_bill_id BIGINT,
    due_date DATE,
    scard_id BIGINT,
    memo TEXT,
    bill_no INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bill_dt ON bill(dt);
CREATE INDEX IF NOT EXISTS idx_bill_op ON bill(op_id);
CREATE INDEX IF NOT EXISTS idx_bill_object ON bill(object_id);
CREATE INDEX IF NOT EXISTS idx_bill_loc ON bill(loc_id);
CREATE INDEX IF NOT EXISTS idx_bill_code ON bill(code);

-- Create bill_line table (bill items)
CREATE TABLE IF NOT EXISTS bill_line (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id) ON DELETE CASCADE,
    goods_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax_percent NUMERIC(6,2) NOT NULL DEFAULT 0,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    unit_id BIGINT,
    ph_qtty NUMERIC(18,4),
    lot_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bill_line_bill ON bill_line(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_line_goods ON bill_line(goods_id);

-- Create amount table (bill amounts)
CREATE TABLE IF NOT EXISTS amount (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id) ON DELETE CASCADE,
    amt_type_id SMALLINT NOT NULL,
    cur_id BIGINT NOT NULL DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_amount_bill ON amount(bill_id);

-- Create barcode table
CREATE TABLE IF NOT EXISTS barcode (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    barcode_type INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_barcode_code ON barcode(code);
CREATE INDEX IF NOT EXISTS idx_barcode_goods ON barcode(goods_id);

-- Create register table (INN, KPP, etc)
CREATE TABLE IF NOT EXISTS register (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    reg_type_id BIGINT NOT NULL,
    number VARCHAR(128) NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_register_person ON register(person_id);

-- Create elink table (phones, emails)
CREATE TABLE IF NOT EXISTS elink (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    kind_id BIGINT NOT NULL,
    address VARCHAR(256) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_elink_person ON elink(person_id);

-- Create operation kinds table
CREATE TABLE IF NOT EXISTS op_kind (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    acc_sheet_id BIGINT,
    acc_sheet2_id BIGINT,
    link_op_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_op_kind_type ON op_kind(type);

-- Create currency table
CREATE TABLE IF NOT EXISTS currency (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL,
    name VARCHAR(256) NOT NULL,
    symbol VARCHAR(8),
    rate NUMERIC(18,9) DEFAULT 1,
    is_base BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create currency rate table
CREATE TABLE IF NOT EXISTS currency_rate (
    id BIGSERIAL PRIMARY KEY,
    cur_id BIGINT NOT NULL,
    rate_type_id BIGINT NOT NULL,
    rel_cur_id BIGINT NOT NULL,
    dt DATE NOT NULL,
    rate NUMERIC(18,9) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cur_id, rate_type_id, rel_cur_id, dt)
);

CREATE INDEX IF NOT EXISTS idx_currency_rate ON currency_rate(cur_id, dt);

-- Create goods stock view
CREATE OR REPLACE VIEW goods_stock AS
SELECT 
    g.id as goods_id,
    g.name as goods_name,
    g.code as goods_code,
    COALESCE(SUM(bl.qtty), 0) as total_qtty,
    l.id as location_id,
    l.name as location_name
FROM goods g
LEFT JOIN bill_line bl ON bl.goods_id = g.id
LEFT JOIN bill b ON b.id = bl.bill_id
LEFT JOIN location l ON l.id = b.loc_id
WHERE g.kind = 0
GROUP BY g.id, g.name, g.code, l.id, l.name;

-- Create bill amounts view
CREATE OR REPLACE VIEW bill_amounts AS
SELECT 
    b.id as bill_id,
    b.code as bill_code,
    b.dt as bill_date,
    b.amount as bill_total,
    a.amt_type_id,
    a.amount as amt_amount,
    a.cur_id as amt_cur_id
FROM bill b
LEFT JOIN amount a ON a.bill_id = b.id;

-- Insert default data
-- Insert base currency
INSERT INTO currency (code, name, symbol, rate, is_base) 
VALUES ('RUB', 'Российский рубль', '₽', 1, TRUE)
ON CONFLICT DO NOTHING;

-- Insert main organization
INSERT INTO person (name, flags, status)
VALUES ('Основная организация', 0, 0)
ON CONFLICT DO NOTHING;

-- Insert main warehouse
INSERT INTO location (name, type, flags)
VALUES ('Основной склад', 1, 2)
ON CONFLICT DO NOTHING;
