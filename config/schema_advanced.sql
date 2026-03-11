-- ============================================================
-- Surypus Advanced Database Schema
-- PostgreSQL 14+ with partitioning, materialized views, and optimization
-- ============================================================

-- ============================================================
-- Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "hstore";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "jsonb";

-- ============================================================
-- Core Tables with Partitioning
-- ============================================================

-- Goods table
CREATE TABLE IF NOT EXISTS goods (
    id BIGSERIAL PRIMARY KEY,
    parent_id BIGINT REFERENCES goods(id),
    name VARCHAR(256) NOT NULL,
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
    description TEXT,
    weight NUMERIC(10,3),
    volume NUMERIC(10,3),
    min_stock NUMERIC(18,4) DEFAULT 0,
    max_stock NUMERIC(18,4),
    reorder_qty NUMERIC(18,4) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT goods_name_not_empty CHECK (length(trim(name)) > 0)
) PARTITION BY RANGE (created_at);

-- Create partitions by month for goods
CREATE TABLE goods_2024_01 PARTITION OF goods FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE goods_2024_02 PARTITION OF goods FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
-- ... more partitions

-- Person table with GIN index for full-text search
CREATE TABLE IF NOT EXISTS person (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    full_name TEXT,
    inn VARCHAR(12),
    kpp VARCHAR(9),
    okpo VARCHAR(10),
    flags INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Full-text search vector
    fts_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('russian', coalesce(name, '')), 'A') ||
        setweight(to_tsvector('russian', coalesce(full_name, '')), 'B') ||
        setweight(to_tsvector('russian', coalesce(inn, '')), 'C')
    ) STORED
);

CREATE INDEX idx_person_fts ON person USING GIN (fts_vector);
CREATE INDEX idx_person_inn ON person (inn) WHERE inn IS NOT NULL;

-- Bill table partitioned by date
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Computed column for year-month partitioning
    year_month TEXT GENERATED ALWAYS AS (to_char(dt, 'YYYY-MM')) STORED
) PARTITION BY RANGE (dt);

-- Bill partitions by month
CREATE TABLE bill_2024_01 PARTITION OF bill FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE bill_2024_02 PARTITION OF bill FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
-- ... more partitions

-- Bill lines table
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Computed column
    line_total NUMERIC(18,4) GENERATED ALWAYS AS (
        round(qtty * price * (1 - discount / 100), 4)
    ) STORED
) PARTITION BY REFERENCE (bill_id);

-- ============================================================
-- Stock and Inventory
-- ============================================================

CREATE TABLE IF NOT EXISTS stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) DEFAULT 0,
    cost NUMERIC(18,4) DEFAULT 0,
    dt DATE DEFAULT CURRENT_DATE,
    reserved_qty NUMERIC(18,4) DEFAULT 0,
    fence_qty NUMERIC(18,4) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, loc_id, dt)
);

-- Lot tracking
CREATE TABLE IF NOT EXISTS lot (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL,
    bill_id BIGINT REFERENCES bill(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    rest_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    cost NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4) DEFAULT 0,
    expiry_date DATE,
    series VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_lot_goods_expiry ON lot (goods_id, expiry_date) WHERE expiry_date IS NOT NULL;

-- Stock movements
CREATE TABLE IF NOT EXISTS stock_movement (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id_from BIGINT,
    loc_id_to BIGINT,
    lot_id BIGINT REFERENCES lot(id),
    bill_id BIGINT REFERENCES bill(id),
    qtty NUMERIC(18,4) NOT NULL,
    cost NUMERIC(18,4),
    movement_type SMALLINT NOT NULL,  -- 1=receipt, 2=issue, 3=transfer, 4=adjustment
    movement_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id BIGINT,
    notes TEXT
) PARTITION BY RANGE (movement_date);

-- Movement partitions
CREATE TABLE stock_movement_2024_01 PARTITION OF stock_movement 
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- ============================================================
-- Financial Transactions
-- ============================================================

CREATE TABLE IF NOT EXISTS account (
    id BIGSERIAL PRIMARY KEY,
    sheet_id BIGINT,
    parent_id BIGINT REFERENCES account(id),
    type SMALLINT NOT NULL DEFAULT 0,  -- 0=active, 1=passive, 2=active-passive
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32) NOT NULL,
    flags INTEGER DEFAULT 0,
    cur_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(code)
);

CREATE TABLE IF NOT EXISTS trans (
    id BIGSERIAL PRIMARY KEY,
    dt DATE NOT NULL,
    op_kind_id BIGINT NOT NULL,
    object_id BIGINT,
    loc_id BIGINT,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT DEFAULT 0,
    c_rate NUMERIC(18,9) DEFAULT 1,
    flags INTEGER DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id BIGINT
) PARTITION BY RANGE (dt);

CREATE TABLE IF NOT EXISTS trans_line (
    id BIGSERIAL PRIMARY KEY,
    trans_id BIGINT NOT NULL REFERENCES trans(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES account(id),
    debit NUMERIC(18,4) DEFAULT 0,
    credit NUMERIC(18,4) DEFAULT 0,
    bill_id BIGINT,
    lot_id BIGINT,
    goods_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Currency and Rates
-- ============================================================

CREATE TABLE IF NOT EXISTS currency (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,
    name VARCHAR(256) NOT NULL,
    symbol VARCHAR(8),
    is_base BOOLEAN DEFAULT FALSE,
    is_default BOOLEAN DEFAULT FALSE,
    rounding NUMERIC(4,2) DEFAULT 0.01,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS currency_rate (
    id BIGSERIAL PRIMARY KEY,
    cur_id BIGINT NOT NULL REFERENCES currency(id),
    rel_cur_id BIGINT NOT NULL REFERENCES currency(id),
    rate_type_id BIGINT DEFAULT 1,
    rate NUMERIC(18,9) NOT NULL,
    dt DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cur_id, rel_cur_id, rate_type_id, dt)
);

CREATE INDEX idx_currency_rate_dt ON currency_rate (dt DESC);

-- ============================================================
-- Price Lists
-- ============================================================

CREATE TABLE IF NOT EXISTS price_list (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    currency_id BIGINT REFERENCES currency(id),
    valid_from DATE,
    valid_to DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS price_list_goods (
    id BIGSERIAL PRIMARY KEY,
    price_list_id BIGINT NOT NULL REFERENCES price_list(id) ON DELETE CASCADE,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price NUMERIC(18,4) NOT NULL,
    discount NUMERIC(6,2) DEFAULT 0,
    min_qtty NUMERIC(18,4) DEFAULT 1,
    start_dt DATE,
    end_dt DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(price_list_id, goods_id, start_dt)
);

-- ============================================================
-- Barcode
-- ============================================================

CREATE TABLE IF NOT EXISTS barcode (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    barcode_type INTEGER DEFAULT 0,
    is_preferred BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(code)
);

CREATE INDEX idx_barcode_goods ON barcode (goods_id);

-- ============================================================
-- Locations
-- ============================================================

CREATE TABLE IF NOT EXISTS location (
    id BIGSERIAL PRIMARY KEY,
    parent_id BIGINT REFERENCES location(id),
    type SMALLINT NOT NULL DEFAULT 0,  -- 0=warehouse, 1=shop, 2=office, etc.
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    address TEXT,
    phone VARCHAR(32),
    email VARCHAR(128),
    coord_x DOUBLE PRECISION,
    coord_y DOUBLE PRECISION,
    main_org_id BIGINT,
    flags INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Users and Security
-- ============================================================

CREATE TABLE IF NOT EXISTS usr (
    id BIGSERIAL PRIMARY KEY,
    login VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    person_id BIGINT REFERENCES person(id),
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS session (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL REFERENCES usr(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    ip_address INET,
    user_agent TEXT
);

CREATE TABLE IF NOT EXISTS permission (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    category VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS user_permission (
    user_id BIGINT NOT NULL REFERENCES usr(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permission(id) ON DELETE CASCADE,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    granted_by BIGINT REFERENCES usr(id),
    PRIMARY KEY (user_id, permission_id)
);

-- Audit log
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    record_id BIGINT NOT NULL,
    operation CHAR(1) NOT NULL,  -- I=insert, U=update, D=delete
    old_data JSONB,
    new_data JSONB,
    user_id BIGINT,
    ip_address INET,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY RANGE (changed_at);

CREATE TABLE audit_log_2024_01 PARTITION OF audit_log 
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- ============================================================
-- Materialized Views for Reporting
-- ============================================================

-- Current stock summary
CREATE MATERIALIZED VIEW mv_current_stock AS
SELECT 
    s.goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    g.barcode,
    s.loc_id,
    l.name AS location_name,
    SUM(s.qtty) AS total_qtty,
    AVG(s.cost) AS avg_cost,
    AVG(s.price) AS avg_price,
    MIN(s.dt) AS first_receipt,
    MAX(s.dt) AS last_receipt
FROM stock s
JOIN goods g ON g.id = s.goods_id
JOIN location l ON l.id = s.loc_id
WHERE s.qtty > 0
GROUP BY s.goods_id, g.name, g.code, g.barcode, s.loc_id, l.name
WITH DATA;

CREATE UNIQUE INDEX idx_mv_stock_goods_loc ON mv_current_stock (goods_id, loc_id);

-- Monthly turnover
CREATE MATERIALIZED VIEW mv_monthly_turnover AS
SELECT 
    to_char(b.dt, 'YYYY-MM') AS period,
    b.loc_id,
    l.name AS location_name,
    b.op_id,
    ok.name AS op_kind_name,
    COUNT(*) AS bill_count,
    SUM(b.amount) AS total_amount,
    SUM(bl.qtty) AS total_qtty
FROM bill b
JOIN bill_line bl ON bl.bill_id = b.id
JOIN location l ON l.id = b.loc_id
JOIN op_kind ok ON ok.id = b.op_id
WHERE b.flags & 1 = 0  -- Only active bills
GROUP BY to_char(b.dt, 'YYYY-MM'), b.loc_id, l.name, b.op_id, ok.name
WITH DATA;

CREATE INDEX idx_mv_turnover_period ON mv_monthly_turnover (period);

-- Receivables
CREATE MATERIALIZED VIEW mv_receivables AS
SELECT 
    b.object_id AS person_id,
    p.name AS person_name,
    b.loc_id,
    l.name AS location_name,
    SUM(b.amount) AS total_due,
    MIN(b.dt) AS earliest_bill,
    MAX(b.dt) AS latest_bill,
    COUNT(*) AS bill_count,
    SUM(CASE WHEN b.due_date < CURRENT_DATE THEN b.amount ELSE 0 END) AS overdue_amount
FROM bill b
JOIN person p ON p.id = b.object_id
JOIN location l ON l.id = b.loc_id
WHERE b.op_id IN (SELECT id FROM op_kind WHERE type = 1)  -- Sales
  AND b.flags & 1 = 0
  AND b.amount > 0
GROUP BY b.object_id, p.name, b.loc_id, l.name
WITH DATA;

-- ============================================================
-- Advanced Functions
-- ============================================================

-- Automatic stock update trigger function
CREATE OR REPLACE FUNCTION fn_stock_after_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Update stock balance
    INSERT INTO stock (goods_id, loc_id, qtty, cost, price, dt)
    VALUES (NEW.goods_id, NEW.loc_id, NEW.qtty, NEW.cost, NEW.price, NEW.dt)
    ON CONFLICT (goods_id, loc_id, dt) 
    DO UPDATE SET 
        qtty = stock.qtty + NEW.qtty,
        cost = (stock.cost * stock.qtty + NEW.cost * NEW.qtty) / (stock.qtty + NEW.qtty);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER tr_stock_after_insert
    AFTER INSERT ON stock_movement
    FOR EACH ROW
    EXECUTE FUNCTION fn_stock_after_insert();

-- Audit trigger function
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, operation, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, 'I', to_jsonb(NEW), current_setting('app.user_id', TRUE)::BIGINT);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_data, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, 'U', to_jsonb(OLD), to_jsonb(NEW), current_setting('app.user_id', TRUE)::BIGINT);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_data, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, 'D', to_jsonb(OLD), current_setting('app.user_id', TRUE)::BIGINT);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit trigger to sensitive tables
CREATE TRIGGER tr_goods_audit
    AFTER INSERT OR UPDATE OR DELETE ON goods
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER tr_person_audit
    AFTER INSERT OR UPDATE OR DELETE ON person
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER tr_bill_audit
    AFTER INSERT OR UPDATE OR DELETE ON bill
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- ============================================================
-- Business Logic Functions
-- ============================================================

-- Calculate goods cost (FIFO)
CREATE OR REPLACE FUNCTION fn_calculate_goods_cost(
    p_goods_id BIGINT,
    p_loc_id BIGINT,
    p_quantity NUMERIC(18,4)
)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_cost NUMERIC(18,4) := 0;
    v_remaining NUMERIC(18,4) := p_quantity;
    v_lot_cost NUMERIC(18,4);
    v_lot_qtty NUMERIC(18,4);
    v_take_qtty NUMERIC(18,4);
BEGIN
    FOR v_lot_cost, v_lot_qtty IN
        SELECT l.cost, l.rest_qtty
        FROM lot l
        WHERE l.goods_id = p_goods_id
          AND l.loc_id = p_loc_id
          AND l.rest_qtty > 0
        ORDER BY l.created_at ASC
    LOOP
        IF v_remaining <= 0 THEN
            EXIT;
        END IF;
        
        v_take_qtty := LEAST(v_remaining, v_lot_qtty);
        v_cost := v_cost + v_lot_cost * v_take_qtty;
        v_remaining := v_remaining - v_take_qtty;
    END LOOP;
    
    RETURN v_cost;
END;
$$ LANGUAGE plpgsql;

-- Reserve stock for order
CREATE OR REPLACE FUNCTION fn_reserve_stock(
    p_goods_id BIGINT,
    p_loc_id BIGINT,
    p_quantity NUMERIC(18,4)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_available NUMERIC(18,4);
    v_reserved NUMERIC(18,4);
BEGIN
    SELECT qtty - reserved_qty INTO v_available
    FROM stock
    WHERE goods_id = p_goods_id AND loc_id = p_loc_id;
    
    IF v_available < p_quantity THEN
        RETURN FALSE;
    END IF;
    
    UPDATE stock 
    SET reserved_qty = reserved_qty + p_quantity
    WHERE goods_id = p_goods_id AND loc_id = p_loc_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Calculate VAT
CREATE OR REPLACE FUNCTION fn_calculate_vat(
    p_amount NUMERIC(18,4),
    p_vat_rate NUMERIC(6,2)
)
RETURNS NUMERIC(18,4) AS $$
BEGIN
    RETURN ROUND(p_amount * p_vat_rate / (100 + p_vat_rate), 2);
END;
$$ LANGUAGE plpgsql;

-- Full-text search
CREATE OR REPLACE FUNCTION fn_search_goods(p_search_text TEXT)
RETURNS TABLE(
    id BIGINT,
    name VARCHAR(256),
    code VARCHAR(16),
    barcode TEXT,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.id,
        g.name,
        g.code,
        g.barcode,
        ts_rank(g.fts_vector, plainto_tsquery('russian', p_search_text)) AS rank
    FROM goods g
    WHERE g.fts_vector @@ plainto_tsquery('russian', p_search_text)
    ORDER BY rank DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Window Functions for Analytics
-- ============================================================

-- Running total of sales
CREATE OR REPLACE FUNCTION fn_running_sales(p_loc_id BIGINT, p_days INT)
RETURNS TABLE(dt DATE, amount NUMERIC(18,4), running_total NUMERIC(18,4)) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.dt,
        b.amount,
        SUM(b.amount) OVER (ORDER BY b.dt) AS running_total
    FROM bill b
    WHERE b.loc_id = p_loc_id
      AND b.dt >= CURRENT_DATE - p_days
      AND b.op_id IN (SELECT id FROM op_kind WHERE type = 2)  -- Sales
    ORDER BY b.dt;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Partition Management
-- ============================================================

-- Auto-create partition for new month
CREATE OR REPLACE FUNCTION fn_create_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    v_partition_date TEXT;
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    v_partition_date := to_char(NEW.dt, 'YYYY_MM');
    v_partition_name := 'bill_' || v_partition_date;
    v_start_date := date_trunc('month', NEW.dt);
    v_end_date := v_start_date + INTERVAL '1 month';
    
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF bill FOR VALUES FROM (%L) TO (%L)',
        v_partition_name, v_start_date, v_end_date
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_create_partition
    BEFORE INSERT ON bill
    FOR EACH ROW
    EXECUTE FUNCTION fn_create_partition_if_not_exists();

-- ============================================================
-- Refresh Materialized Views (for cron)
-- ============================================================

CREATE OR REPLACE FUNCTION fn_refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_current_stock;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_turnover;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_receivables;
    
    -- Analyze tables for query planner
    ANALYZE stock;
    ANALYZE bill;
    ANALYZE bill_line;
    ANALYZE trans;
    ANALYZE trans_line;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT USAGE ON SCHEMA public TO surypus;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO surypus;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO surypus;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO surypus;
