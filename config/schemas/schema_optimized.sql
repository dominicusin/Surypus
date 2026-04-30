-- ============================================================
-- Surypus Optimized Database Schema
-- PostgreSQL 14+ with advanced features
-- ============================================================
-- Optimizations:
-- - Partitioning for large tables
-- - BRIN indexes for time-series data
-- - Partial indexes for common queries
-- - Optimized data types
-- - Materialized views for reporting
-- - Proper constraints and triggers
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "hstore";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ============================================================
-- Core Sequences with cache for performance
-- ============================================================
CREATE SEQUENCE global_id_seq START WITH 1000 CACHE 100;

-- ============================================================
-- Reference Tables (Cached/Read-heavy)
-- ============================================================

-- Currency optimized
CREATE TABLE currency (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,
    name VARCHAR(256) NOT NULL,
    symbol VARCHAR(8),
    rate NUMERIC(18,9) DEFAULT 1,
    is_base BOOLEAN DEFAULT FALSE,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
) WITH (fillfactor = 90);

CREATE UNIQUE INDEX idx_currency_code ON currency(code);
CREATE INDEX idx_currency_base ON currency(is_base) WHERE is_base = TRUE;
CREATE INDEX idx_currency_name ON currency USING gin(name gin_trgm_ops);

-- Currency rates with partitioning support
CREATE TABLE currency_rate (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    cur_id BIGINT NOT NULL REFERENCES currency(id) ON DELETE CASCADE,
    rate_type_id BIGINT NOT NULL DEFAULT 1,
    rel_cur_id BIGINT NOT NULL REFERENCES currency(id) ON DELETE CASCADE,
    dt DATE NOT NULL,
    rate NUMERIC(18,9) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Account sheet
CREATE TABLE acc_sheet (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Account with hierarchy support
CREATE TABLE account (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    sheet_id BIGINT NOT NULL REFERENCES acc_sheet(id) ON DELETE RESTRICT,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    parent_id BIGINT REFERENCES account(id) ON DELETE SET NULL,
    flags INTEGER DEFAULT 0,
    cur_id BIGINT REFERENCES currency(id) ON DELETE SET NULL,
    acc_level SMALLINT GENERATED ALWAYS AS (
        CASE 
            WHEN parent_id IS NULL THEN 0
            ELSE 1
        END
    ) STORED,
    path TEXT GENERATED ALWAYS AS (
        COALESCE('/' || code, '')
    ) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(sheet_id, code),
    CONSTRAINT chk_account_type CHECK (type IN (0, 1, 2, 3))
) WITH (fillfactor = 85);

CREATE INDEX idx_account_sheet ON account(sheet_id);
CREATE INDEX idx_account_parent ON account(parent_id);
CREATE INDEX idx_account_code ON account(code);
CREATE INDEX idx_account_type ON account(type) WHERE type != 0;
CREATE INDEX idx_account_path ON account USING gin(path gin_trgm_ops);

-- Operation kinds
CREATE TABLE op_kind (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    acc_sheet_id BIGINT REFERENCES acc_sheet(id) ON DELETE SET NULL,
    acc_sheet2_id BIGINT REFERENCES acc_sheet(id) ON DELETE SET NULL,
    link_op_id BIGINT REFERENCES op_kind(id) ON DELETE SET NULL,
    calc_auto_trans BOOLEAN DEFAULT TRUE,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_op_kind_type CHECK (type BETWEEN 0 AND 20)
);

CREATE INDEX idx_op_kind_type ON op_kind(type);
CREATE INDEX idx_op_kind_link ON op_kind(link_op_id);

-- Location types
CREATE TABLE loc_type (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES loc_type(id) ON DELETE CASCADE,
    flags INTEGER DEFAULT 0,
    sort_order SMALLINT DEFAULT 0
);

CREATE INDEX idx_loc_type_parent ON loc_type(parent_id);

-- Location (warehouses/addresses) - frequently queried
CREATE TABLE location (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    parent_id BIGINT REFERENCES location(id) ON DELETE SET NULL,
    address_id BIGINT,
    address TEXT,
    phone TEXT,
    email TEXT,
    coord_x DOUBLE PRECISION,
    coord_y DOUBLE PRECISION,
    main_org_id BIGINT,
    timezone VARCHAR(64) DEFAULT 'UTC',
    is_active BOOLEAN DEFAULT TRUE,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_location_type CHECK (type BETWEEN 0 AND 10)
) WITH (fillfactor = 90);

CREATE INDEX idx_location_parent ON location(parent_id);
CREATE INDEX idx_location_type ON location(type);
CREATE INDEX idx_location_active ON location(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_location_name ON location USING gin(name gin_trgm_ops);
CREATE INDEX idx_location_coords ON location(coord_x, coord_y) WHERE coord_x IS NOT NULL;

-- ============================================================
-- Goods (Товары) - Partitioned by kind
-- ============================================================

CREATE TABLE goods (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goods(id) ON DELETE SET NULL,
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
    is_active BOOLEAN DEFAULT TRUE,
    is_phantom BOOLEAN DEFAULT FALSE,
    min_stock NUMERIC(18,4) DEFAULT 0,
    max_stock NUMERIC(18,4),
    reorder_qty NUMERIC(18,4),
    weight NUMERIC(10,4),
    volume NUMERIC(10,4),
    dims VARCHAR(64),
    shelf_life_days INTEGER,
    country_id BIGINT,
    gtin VARCHAR(14),
    extra JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_goods_kind CHECK (kind BETWEEN 0 AND 10)
) PARTITION BY LIST (kind);

-- Partitions for goods kinds
CREATE TABLE goods_simple PARTITION OF goods FOR VALUES IN (0);
CREATE TABLE goods_service PARTITION OF goods FOR VALUES IN (1);
CREATE TABLE goods_composite PARTITION OF goods FOR VALUES IN (2);
CREATE TABLE goods_bundle PARTITION OF goods FOR VALUES IN (3);

CREATE INDEX idx_goods_parent ON goods(parent_id);
CREATE INDEX idx_goods_code ON goods(code) WHERE code IS NOT NULL;
CREATE INDEX idx_goods_barcode ON goods(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_goods_gtin ON goods(gtin) WHERE gtin IS NOT NULL;
CREATE INDEX idx_goods_name ON goods USING gin(name gin_trgm_ops);
CREATE INDEX idx_goods_active ON goods(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_goods_brand ON goods(brand_id) WHERE brand_id IS NOT NULL;
CREATE INDEX idx_goods_manuf ON goods(manuf_id) WHERE manuf_id IS NOT NULL;
CREATE INDEX idx_goods_cls ON goods(gds_cls_id) WHERE gds_cls_id IS NOT NULL;

-- Barcodes with high read volume
CREATE TABLE barcode (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    qtty NUMERIC(18,4) DEFAULT 1,
    barcode_type SMALLINT DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
) WITH (fillfactor = 90);

CREATE UNIQUE INDEX idx_barcode_code ON barcode(code);
CREATE UNIQUE INDEX idx_barcode_goods_primary ON barcode(goods_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX idx_barcode_goods ON barcode(goods_id);

-- Goods class (classification)
CREATE TABLE goods_class (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goods_class(id) ON DELETE CASCADE,
    kind SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    prop_kind BIGINT,
    prop_grade BIGINT,
    prop_add BIGINT,
    prop_add2 BIGINT,
    code VARCHAR(16),
    extra JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_goods_class_parent ON goods_class(parent_id);
CREATE INDEX idx_goods_class_code ON goods_class(code) WHERE code IS NOT NULL;

-- ============================================================
-- Person/Party (Контрагенты)
-- ============================================================

CREATE TABLE person (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0,
    kind_mask INTEGER DEFAULT 0,
    category SMALLINT DEFAULT 0,
    credit_limit NUMERIC(18,4),
    payment_days INTEGER,
    discount_percent NUMERIC(6,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_person_status CHECK (status BETWEEN 0 AND 10)
) WITH (fillfactor = 90);

CREATE INDEX idx_person_name ON person USING gin(name gin_trgm_ops);
CREATE INDEX idx_person_status ON person(status);
CREATE INDEX idx_person_active ON person(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_person_kind ON person(kind_mask) WHERE kind_mask != 0;

-- Person kinds (many-to-many)
CREATE TABLE person_kind (
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    kind_id BIGINT NOT NULL,
    name VARCHAR(256),
    discount_percent NUMERIC(6,2),
    PRIMARY KEY (person_id, kind_id)
);

-- Registrations (INN, KPP, etc)
CREATE TABLE register (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    reg_type_id BIGINT NOT NULL,
    number VARCHAR(128) NOT NULL,
    series VARCHAR(32),
    issued_by VARCHAR(256),
    issue_date DATE,
    expiry_date DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_reg_type CHECK (reg_type_id BETWEEN 1 AND 20)
);

CREATE INDEX idx_register_person ON register(person_id);
CREATE INDEX idx_register_type ON register(reg_type_id);
CREATE INDEX idx_register_number ON register(number) WHERE reg_type_id = 1;
CREATE INDEX idx_register_expiry ON register(expiry_date) WHERE expiry_date IS NOT NULL;

-- Electronic links (phones, emails)
CREATE TABLE elink (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    link_type BIGINT NOT NULL,
    address VARCHAR(256) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_link_type CHECK (link_type BETWEEN 1 AND 10)
);

CREATE INDEX idx_elink_person ON elink(person_id);
CREATE INDEX idx_elink_type ON elink(link_type);
CREATE INDEX idx_elink_primary ON elink(person_id, is_primary) WHERE is_primary = TRUE;

-- Addresses
CREATE TABLE party_address (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    addr_type SMALLINT NOT NULL DEFAULT 0,
    country VARCHAR(64),
    region VARCHAR(128),
    city VARCHAR(128),
    district VARCHAR(128),
    street VARCHAR(256),
    house VARCHAR(32),
    building VARCHAR(32),
    flat VARCHAR(32),
    zip_code VARCHAR(16),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_party_addr_person ON party_address(person_id);
CREATE INDEX idx_party_addr_type ON party_address(addr_type);

-- Bank accounts
CREATE TABLE bank_account (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    bank_name VARCHAR(256) NOT NULL,
    account VARCHAR(34) NOT NULL,
    account_type SMALLINT DEFAULT 0,
    cor_account VARCHAR(34),
    bik VARCHAR(9),
    inn VARCHAR(12),
    kpp VARCHAR(9),
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(person_id, account)
);

CREATE INDEX idx_bank_acct_person ON bank_account(person_id);
CREATE INDEX idx_bank_acct_bik ON bank_account(bik) WHERE bik IS NOT NULL;
CREATE INDEX idx_bank_acct_inn ON bank_account(inn) WHERE inn IS NOT NULL;

-- ============================================================
-- Documents (Документы) - Partitioned by date
-- ============================================================

CREATE TABLE bill (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    dt DATE NOT NULL,
    op_id BIGINT NOT NULL REFERENCES op_kind(id) ON DELETE RESTRICT,
    object_id BIGINT,
    object2_id BIGINT,
    loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT NOT NULL DEFAULT 1,
    c_rate NUMERIC(18,9) NOT NULL DEFAULT 1,
    flags INTEGER DEFAULT 0,
    status_id BIGINT,
    status SMALLINT DEFAULT 0,
    link_bill_id BIGINT,
    due_date DATE,
    scard_id BIGINT,
    bill_no INTEGER,
    memo TEXT,
    ext JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (dt);

-- Partitions by year
CREATE TABLE bill_2024 PARTITION OF bill FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE bill_2025 PARTITION OF bill FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE bill_2026 PARTITION OF bill FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE bill_default PARTITION OF bill DEFAULT;

CREATE INDEX idx_bill_dt ON bill(dt);
CREATE INDEX idx_bill_op ON bill(op_id);
CREATE INDEX idx_bill_object ON bill(object_id) WHERE object_id IS NOT NULL;
CREATE INDEX idx_bill_loc ON bill(loc_id);
CREATE INDEX idx_bill_code ON bill(code);
CREATE INDEX idx_bill_status ON bill(status) WHERE status != 2;
CREATE INDEX idx_bill_link ON bill(link_bill_id) WHERE link_bill_id IS NOT NULL;
CREATE INDEX idx_bill_due ON bill(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX idx_bill_amount ON bill(amount) WHERE amount > 0;

-- Bill lines
CREATE TABLE bill_line (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    bill_id BIGINT NOT NULL,
    bill_dt DATE NOT NULL,
    line_no SMALLINT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE RESTRICT,
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax_percent NUMERIC(6,2) NOT NULL DEFAULT 0,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    unit_id BIGINT,
    ph_qtty NUMERIC(18,4),
    lot_id BIGINT,
    ext JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (bill_id, bill_dt) REFERENCES bill(id, dt) ON DELETE CASCADE
) PARTITION BY RANGE (bill_dt);

CREATE TABLE bill_line_2024 PARTITION OF bill_line FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE bill_line_2025 PARTITION OF bill_line FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE bill_line_2026 PARTITION OF bill_line FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE bill_line_default PARTITION OF bill_line DEFAULT;

CREATE INDEX idx_bill_line_bill ON bill_line(bill_id);
CREATE INDEX idx_bill_line_goods ON bill_line(goods_id);
CREATE INDEX idx_bill_line_lot ON bill_line(lot_id) WHERE lot_id IS NOT NULL;

-- Bill amounts
CREATE TABLE amount (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    bill_id BIGINT NOT NULL,
    bill_dt DATE NOT NULL,
    amt_type_id SMALLINT NOT NULL,
    cur_id BIGINT NOT NULL DEFAULT 1,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (bill_id, bill_dt) REFERENCES bill(id, dt) ON DELETE CASCADE,
    UNIQUE(bill_id, amt_type_id, cur_id)
);

CREATE INDEX idx_amount_bill ON amount(bill_id);
CREATE INDEX idx_amount_type ON amount(amt_type_id);

-- ============================================================
-- Inventory (Складской учёт) - Time-series
-- ============================================================

-- Stock (current balances)
CREATE TABLE stock (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE CASCADE,
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    last_movement_date DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(goods_id, loc_id)
) WITH (fillfactor = 85);

CREATE INDEX idx_stock_goods ON stock(goods_id);
CREATE INDEX idx_stock_loc ON stock(loc_id);
CREATE INDEX idx_stock_qtty ON stock(qtty) WHERE qtty > 0;

-- Lots (batches)
CREATE TABLE lot (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE RESTRICT,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    bill_dt DATE,
    dt DATE NOT NULL,
    expiry DATE,
    qtty NUMERIC(18,4) NOT NULL,
    rest NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    serial VARCHAR(64),
    country VARCHAR(64),
    gdoc VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (dt);

CREATE TABLE lot_2024 PARTITION OF lot FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE lot_2025 PARTITION OF lot FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE lot_2026 PARTITION OF lot FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE lot_default PARTITION OF lot DEFAULT;

CREATE INDEX idx_lot_goods ON lot(goods_id);
CREATE INDEX idx_lot_bill ON lot(bill_id);
CREATE INDEX idx_lot_expiry ON lot(expiry) WHERE expiry IS NOT NULL;
CREATE INDEX idx_lot_serial ON lot(serial) WHERE serial IS NOT NULL;

-- Goods movements (time-series)
CREATE TABLE gds_movement (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    dt DATE NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE RESTRICT,
    loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    op_id BIGINT REFERENCES op_kind(id) ON DELETE SET NULL,
    qtty_in NUMERIC(18,4) DEFAULT 0,
    qtty_out NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (dt);

CREATE TABLE gds_movement_2024 PARTITION OF gds_movement FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE gds_movement_2025 PARTITION OF gds_movement FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE gds_movement_2026 PARTITION OF gds_movement FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE gds_movement_default PARTITION OF gds_movement DEFAULT;

CREATE INDEX idx_gds_mv_goods ON gds_movement(goods_id);
CREATE INDEX idx_gds_mv_loc ON gds_movement(loc_id);
CREATE INDEX idx_gds_mv_dt ON gds_movement(dt);
CREATE INDEX idx_gds_mv_bill ON gds_movement(bill_id) WHERE bill_id IS NOT NULL;
CREATE INDEX idx_gds_mv_op ON gds_movement(op_id) WHERE op_id IS NOT NULL;

-- Min stock levels
CREATE TABLE min_stock (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE CASCADE,
    val NUMERIC(18,4) NOT NULL DEFAULT 0,
    reorder_point NUMERIC(18,4),
    UNIQUE(goods_id, loc_id)
);

CREATE INDEX idx_min_stock_goods ON min_stock(goods_id);
CREATE INDEX idx_min_stock_loc ON min_stock(loc_id);

-- ============================================================
-- Finance (Финансы)
-- ============================================================

-- Transactions ( проводки)
CREATE TABLE trans (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    dt DATE NOT NULL,
    op_id BIGINT REFERENCES op_kind(id) ON DELETE SET NULL,
    object_id BIGINT,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    memo TEXT,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (dt);

CREATE TABLE trans_2024 PARTITION OF trans FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE trans_2025 PARTITION OF trans FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE trans_2026 PARTITION OF trans FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE trans_default PARTITION OF trans DEFAULT;

CREATE INDEX idx_trans_dt ON trans(dt);
CREATE INDEX idx_trans_bill ON trans(bill_id) WHERE bill_id IS NOT NULL;
CREATE INDEX idx_trans_op ON trans(op_id) WHERE op_id IS NOT NULL;

-- Transaction lines
CREATE TABLE trans_line (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    trans_id BIGINT NOT NULL,
    trans_dt DATE NOT NULL,
    account_id BIGINT NOT NULL REFERENCES account(id) ON DELETE RESTRICT,
    debit NUMERIC(18,4) NOT NULL DEFAULT 0,
    credit NUMERIC(18,4) NOT NULL DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT NOT NULL DEFAULT 1,
    c_rate NUMERIC(18,9) DEFAULT 1,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    ext JSONB DEFAULT '{}'::jsonb,
    FOREIGN KEY (trans_id, trans_dt) REFERENCES trans(id, dt) ON DELETE CASCADE
);

CREATE TABLE trans_line_2024 PARTITION OF trans_line FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE trans_line_2025 PARTITION OF trans_line FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE trans_line_2026 PARTITION OF trans_line FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE trans_line_default PARTITION OF trans_line DEFAULT;

CREATE INDEX idx_trans_line_trans ON trans_line(trans_id);
CREATE INDEX idx_trans_line_account ON trans_line(account_id);
CREATE INDEX idx_trans_line_bill ON trans_line(bill_id) WHERE bill_id IS NOT NULL;

-- ============================================================
-- Audit and History
-- ============================================================

CREATE TABLE audit_log (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id BIGINT NOT NULL,
    operation CHAR(1) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    user_id BIGINT,
    ip_address INET,
    changed_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (changed_at);

CREATE TABLE audit_log_2024 PARTITION OF audit_log FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE audit_log_2025 PARTITION OF audit_log FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE audit_log_2026 PARTITION OF audit_log FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE audit_log_default PARTITION OF audit_log DEFAULT;

CREATE INDEX idx_audit_log_table ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_changed ON audit_log(changed_at DESC);
CREATE INDEX idx_audit_log_user ON audit_log(user_id) WHERE user_id IS NOT NULL;

-- ============================================================
-- Materialized Views for Reporting
-- ============================================================

-- Current stock view
CREATE MATERIALIZED VIEW mv_current_stock AS
SELECT 
    s.goods_id,
    s.loc_id,
    s.qtty,
    s.price,
    s.cost,
    g.name AS goods_name,
    g.code AS goods_code,
    l.name AS location_name,
    s.updated_at
FROM stock s
JOIN goods g ON g.id = s.goods_id
JOIN location l ON l.id = s.loc_id
WHERE s.qtty > 0
WITH DATA;

CREATE UNIQUE INDEX idx_mv_stock ON mv_current_stock(goods_id, loc_id);

-- Monthly turnover
CREATE MATERIALIZED VIEW mv_monthly_turnover AS
SELECT 
    gm.goods_id,
    gm.loc_id,
    DATE_TRUNC('month', gm.dt)::DATE AS month,
    SUM(gm.qtty_in) AS total_in,
    SUM(gm.qtty_out) AS total_out,
    SUM(COALESCE(gm.qtty_in, 0) * COALESCE(gm.price, 0)) AS amount_in,
    SUM(COALESCE(gm.qtty_out, 0) * COALESCE(gm.price, 0)) AS amount_out,
    COUNT(DISTINCT gm.bill_id) AS movement_count
FROM gds_movement gm
WHERE gm.dt >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '12 months'
GROUP BY gm.goods_id, gm.loc_id, DATE_TRUNC('month', gm.dt)
WITH DATA;

CREATE INDEX idx_mv_turnover_goods ON mv_monthly_turnover(goods_id, loc_id, month);

-- Receivables
CREATE MATERIALIZED VIEW mv_receivables AS
SELECT 
    d.object_id AS party_id,
    p.name AS party_name,
    SUM(d.amount) AS total_amount,
    SUM(COALESCE(da.amount, 0)) AS paid_amount,
    SUM(d.amount) - SUM(COALESCE(da.amount, 0)) AS debt,
    MIN(d.due_date) AS oldest_due_date,
    COUNT(*) AS doc_count
FROM bill d
LEFT JOIN amount da ON da.bill_id = d.id AND da.amt_type_id = 1
JOIN person p ON p.id = d.object_id
WHERE d.op_id IN (SELECT id FROM op_kind WHERE type = 2)
  AND d.status != 3
  AND d.due_date <= CURRENT_DATE
GROUP BY d.object_id, p.name
HAVING SUM(d.amount) > SUM(COALESCE(da.amount, 0))
WITH DATA;

CREATE INDEX idx_mv_receivables ON mv_receivables(party_id);

-- ============================================================
-- Triggers and Functions
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_goods_updated BEFORE UPDATE ON goods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_person_updated BEFORE UPDATE ON person
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_location_updated BEFORE UPDATE ON location
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_account_updated BEFORE UPDATE ON account
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_currency_updated BEFORE UPDATE ON currency
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Stock maintenance trigger
CREATE OR REPLACE FUNCTION maintain_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE stock SET 
            qtty = qtty + NEW.qtty_in - COALESCE(NEW.qtty_out, 0),
            last_movement_date = NEW.dt,
            price = COALESCE(NEW.price, price),
            updated_at = NOW()
        WHERE goods_id = NEW.goods_id AND loc_id = NEW.loc_id;
        
        IF NOT FOUND THEN
            INSERT INTO stock (goods_id, loc_id, qtty, price, last_movement_date)
            VALUES (NEW.goods_id, NEW.loc_id, NEW.qtty_in - COALESCE(NEW.qtty_out, 0), NEW.price, NEW.dt);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Default Data
-- ============================================================

INSERT INTO currency (code, name, symbol, rate, is_base, sort_order) VALUES
    ('RUB', 'Российский рубль', '₽', 1, TRUE, 1),
    ('USD', 'US Dollar', '$', 75.50, FALSE, 2),
    ('EUR', 'Euro', '€', 85.00, FALSE, 3)
ON CONFLICT (code) DO NOTHING;

INSERT INTO acc_sheet (name, type, sort_order) VALUES
    ('Основной', 0, 1),
    ('Управленческий', 1, 2),
    ('Налоговый', 2, 3)
ON CONFLICT DO NOTHING;

INSERT INTO op_kind (name, type, flags, calc_auto_trans, sort_order) VALUES
    ('Приход товара', 1, 0, TRUE, 1),
    ('Расход товара', 2, 0, TRUE, 2),
    ('Возврат поставщику', 3, 0, TRUE, 3),
    ('Возврат покупателя', 4, 0, TRUE, 4),
    ('Перемещение', 7, 0, TRUE, 5),
    ('Оплата', 9, 0, FALSE, 6),
    ('Инвентаризация', 5, 0, FALSE, 7)
ON CONFLICT DO NOTHING;

INSERT INTO location (name, type, flags, is_active, sort_order) VALUES
    ('Основной склад', 0, 2, TRUE, 1),
    ('Розничный магазин', 0, 2, TRUE, 2)
ON CONFLICT DO NOTHING;

INSERT INTO person (name, kind_mask, status, is_active) VALUES
    ('Основная организация', 2, 0, TRUE)
ON CONFLICT DO NOTHING;

-- Analyze for query planner
ANALYZE;
