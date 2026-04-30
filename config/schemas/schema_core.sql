-- Add missing core tables to optimized database
-- Run this after schema_optimized.sql and schema_migration.sql

-- Goods
CREATE TABLE IF NOT EXISTS goods (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT,
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
    extra JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goods_parent ON goods(parent_id);
CREATE INDEX IF NOT EXISTS idx_goods_code ON goods(code) WHERE code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_goods_barcode ON goods(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_goods_name ON goods USING gin(name gin_trgm_ops);

-- Barcode
CREATE TABLE IF NOT EXISTS barcode (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    goods_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) DEFAULT 1,
    barcode_type SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_barcode_code ON barcode(code);

-- Stock
CREATE TABLE IF NOT EXISTS stock (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL,
    loc_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    last_movement_date DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(goods_id, loc_id)
);

CREATE INDEX IF NOT EXISTS idx_stock_goods ON stock(goods_id);
CREATE INDEX IF NOT EXISTS idx_stock_loc ON stock(loc_id);

-- Bill
CREATE TABLE IF NOT EXISTS bill (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    dt DATE NOT NULL,
    op_id BIGINT NOT NULL,
    object_id BIGINT,
    object2_id BIGINT,
    loc_id BIGINT NOT NULL,
    amount NUMERIC(18,4) DEFAULT 0,
    cur_id BIGINT DEFAULT 1,
    c_rate NUMERIC(18,9) DEFAULT 1,
    flags INTEGER DEFAULT 0,
    status_id BIGINT,
    status SMALLINT DEFAULT 0,
    link_bill_id BIGINT,
    due_date DATE,
    scard_id BIGINT,
    memo TEXT,
    ext JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bill_dt ON bill(dt);
CREATE INDEX IF NOT EXISTS idx_bill_op ON bill(op_id);
CREATE INDEX IF NOT EXISTS idx_bill_loc ON bill(loc_id);
CREATE INDEX IF NOT EXISTS idx_bill_status ON bill(status) WHERE status != 2;

-- Bill Line
CREATE TABLE IF NOT EXISTS bill_line (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    bill_id BIGINT NOT NULL,
    line_no SMALLINT NOT NULL,
    goods_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4) DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0,
    tax NUMERIC(18,4) DEFAULT 0,
    tax_percent NUMERIC(6,2) DEFAULT 0,
    total NUMERIC(18,4) DEFAULT 0,
    unit_id BIGINT,
    lot_id BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bill_line_bill ON bill_line(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_line_goods ON bill_line(goods_id);

-- Amount
CREATE TABLE IF NOT EXISTS amount (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    bill_id BIGINT NOT NULL,
    amt_type_id SMALLINT NOT NULL,
    cur_id BIGINT DEFAULT 1,
    amount NUMERIC(18,4) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(bill_id, amt_type_id, cur_id)
);

-- Lot
CREATE TABLE IF NOT EXISTS lot (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL,
    bill_id BIGINT,
    dt DATE NOT NULL,
    expiry DATE,
    qtty NUMERIC(18,4) NOT NULL,
    rest NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    serial VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lot_goods ON lot(goods_id);
CREATE INDEX IF NOT EXISTS idx_lot_expiry ON lot(expiry) WHERE expiry IS NOT NULL;

-- Goods Movement
CREATE TABLE IF NOT EXISTS gds_movement (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    dt DATE NOT NULL,
    goods_id BIGINT NOT NULL,
    loc_id BIGINT NOT NULL,
    bill_id BIGINT,
    op_id BIGINT,
    qtty_in NUMERIC(18,4) DEFAULT 0,
    qtty_out NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gds_mv_goods ON gds_movement(goods_id);
CREATE INDEX IF NOT EXISTS idx_gds_mv_loc ON gds_movement(loc_id);
CREATE INDEX IF NOT EXISTS idx_gds_mv_dt ON gds_movement(dt);

-- Transfer
CREATE TABLE IF NOT EXISTS transfer (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    src_loc_id BIGINT NOT NULL,
    dst_loc_id BIGINT NOT NULL,
    goods_id BIGINT,
    qtty NUMERIC(18,4),
    price NUMERIC(18,4),
    status SMALLINT DEFAULT 0,
    dt DATE NOT NULL,
    shipped_dt DATE,
    received_dt DATE,
    waybill_no VARCHAR(32),
    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transfer_src ON transfer(src_loc_id);
CREATE INDEX IF NOT EXISTS idx_transfer_dst ON transfer(dst_loc_id);
CREATE INDEX IF NOT EXISTS idx_transfer_dt ON transfer(dt);

-- Tax Invoice
CREATE TABLE IF NOT EXISTS tax_invoice (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    bill_id BIGINT,
    dt DATE NOT NULL,
    number VARCHAR(16) NOT NULL,
    seller_id BIGINT,
    buyer_id BIGINT,
    total NUMERIC(18,4) DEFAULT 0,
    vat NUMERIC(18,4) DEFAULT 0,
    total_vat NUMERIC(18,4) DEFAULT 0,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number)
);

-- EDI Message
CREATE TABLE IF NOT EXISTS edi_message (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    msg_type SMALLINT NOT NULL,
    direction SMALLINT NOT NULL,
    partner_id BIGINT,
    bill_id BIGINT,
    content TEXT,
    status SMALLINT DEFAULT 0,
    error TEXT,
    dt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_edi_msg_dt ON edi_message(dt);
CREATE INDEX IF NOT EXISTS idx_edi_msg_status ON edi_message(status);

-- EGAIS Mark
CREATE TABLE IF NOT EXISTS egais_mark (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(68) NOT NULL,
    goods_id BIGINT NOT NULL,
    bill_id BIGINT,
    status SMALLINT DEFAULT 0,
    scan_dt TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

CREATE INDEX IF NOT EXISTS idx_egais_mark_goods ON egais_mark(goods_id);

-- Min Stock
CREATE TABLE IF NOT EXISTS min_stock (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL,
    loc_id BIGINT NOT NULL,
    val NUMERIC(18,4) DEFAULT 0,
    reorder_point NUMERIC(18,4),
    UNIQUE(goods_id, loc_id)
);

-- Inventory Line
CREATE TABLE IF NOT EXISTS inventory_line (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    inv_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL,
    lot_id BIGINT,
    fact_qtty NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4),
    diff NUMERIC(18,4),
    cost NUMERIC(18,4)
);

CREATE INDEX IF NOT EXISTS idx_inv_line_inv ON inventory_line(inv_id);
CREATE INDEX IF NOT EXISTS idx_inv_line_goods ON inventory_line(goods_id);

-- Price List Goods
CREATE TABLE IF NOT EXISTS price_list_goods (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    price_list_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    discount_percent NUMERIC(6,2) DEFAULT 0,
    min_qtty NUMERIC(18,4) DEFAULT 1,
    start_dt DATE,
    end_dt DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(price_list_id, goods_id, start_dt)
);

-- Composite Struct
CREATE TABLE IF NOT EXISTS composite_struct (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL,
    component_goods_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) DEFAULT 1,
    yield_percent NUMERIC(6,2),
    is_optional BOOLEAN DEFAULT FALSE,
    seq_no INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(goods_id, component_goods_id)
);

-- Production Order
CREATE TABLE IF NOT EXISTS production_order (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    order_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL,
    qtty NUMERIC(18,4) NOT NULL,
    loc_id BIGINT NOT NULL,
    work_center_id BIGINT,
    due_date DATE,
    priority SMALLINT DEFAULT 1,
    status SMALLINT DEFAULT 1,
    dt DATE NOT NULL,
    start_dt TIMESTAMPTZ,
    complete_dt TIMESTAMPTZ,
    cancel_dt TIMESTAMPTZ,
    cancel_reason TEXT,
    actual_qtty NUMERIC(18,4),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(order_no)
);

-- Add foreign key constraints
ALTER TABLE goods ADD CONSTRAINT fk_goods_parent FOREIGN KEY (parent_id) REFERENCES goods(id) ON DELETE SET NULL;
ALTER TABLE goods ADD CONSTRAINT fk_goods_unit FOREIGN KEY (unit_id) REFERENCES unit(id) ON DELETE SET NULL;
ALTER TABLE goods ADD CONSTRAINT fk_goods_tax_grp FOREIGN KEY (tax_grp_id) REFERENCES tax_group(id) ON DELETE SET NULL;

ALTER TABLE barcode ADD CONSTRAINT fk_barcode_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE CASCADE;
ALTER TABLE stock ADD CONSTRAINT fk_stock_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE CASCADE;
ALTER TABLE stock ADD CONSTRAINT fk_stock_loc FOREIGN KEY (loc_id) REFERENCES location(id) ON DELETE CASCADE;

ALTER TABLE bill ADD CONSTRAINT fk_bill_op FOREIGN KEY (op_id) REFERENCES op_kind(id) ON DELETE RESTRICT;
ALTER TABLE bill ADD CONSTRAINT fk_bill_loc FOREIGN KEY (loc_id) REFERENCES location(id) ON DELETE RESTRICT;
ALTER TABLE bill ADD CONSTRAINT fk_bill_object FOREIGN KEY (object_id) REFERENCES person(id) ON DELETE SET NULL;

ALTER TABLE bill_line ADD CONSTRAINT fk_bill_line_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE CASCADE;
ALTER TABLE bill_line ADD CONSTRAINT fk_bill_line_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE RESTRICT;

ALTER TABLE amount ADD CONSTRAINT fk_amount_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE CASCADE;

ALTER TABLE lot ADD CONSTRAINT fk_lot_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE RESTRICT;
ALTER TABLE lot ADD CONSTRAINT fk_lot_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE SET NULL;

ALTER TABLE gds_movement ADD CONSTRAINT fk_gds_mv_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE RESTRICT;
ALTER TABLE gds_movement ADD CONSTRAINT fk_gds_mv_loc FOREIGN KEY (loc_id) REFERENCES location(id) ON DELETE RESTRICT;
ALTER TABLE gds_movement ADD CONSTRAINT fk_gds_mv_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE SET NULL;

ALTER TABLE transfer ADD CONSTRAINT fk_transfer_src_loc FOREIGN KEY (src_loc_id) REFERENCES location(id) ON DELETE RESTRICT;
ALTER TABLE transfer ADD CONSTRAINT fk_transfer_dst_loc FOREIGN KEY (dst_loc_id) REFERENCES location(id) ON DELETE RESTRICT;
ALTER TABLE transfer ADD CONSTRAINT fk_transfer_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE SET NULL;

ALTER TABLE tax_invoice ADD CONSTRAINT fk_tax_inv_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE SET NULL;
ALTER TABLE tax_invoice ADD CONSTRAINT fk_tax_inv_seller FOREIGN KEY (seller_id) REFERENCES person(id) ON DELETE SET NULL;
ALTER TABLE tax_invoice ADD CONSTRAINT fk_tax_inv_buyer FOREIGN KEY (buyer_id) REFERENCES person(id) ON DELETE SET NULL;

ALTER TABLE edi_message ADD CONSTRAINT fk_edi_msg_partner FOREIGN KEY (partner_id) REFERENCES edi_partner(id) ON DELETE SET NULL;
ALTER TABLE edi_message ADD CONSTRAINT fk_edi_msg_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE SET NULL;

ALTER TABLE egais_mark ADD CONSTRAINT fk_egais_mark_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE RESTRICT;
ALTER TABLE egais_mark ADD CONSTRAINT fk_egais_mark_bill FOREIGN KEY (bill_id) REFERENCES bill(id) ON DELETE SET NULL;

ALTER TABLE min_stock ADD CONSTRAINT fk_min_stock_goods FOREIGN KEY (goods_id) REFERENCES goods(id) ON DELETE CASCADE;
ALTER TABLE min_stock ADD CONSTRAINT fk_min_stock_loc FOREIGN KEY (loc_id) REFERENCES location(id) ON DELETE CASCADE;

-- Update statistics
ANALYZE;

-- Final count
DO $$
DECLARE
    tbl_count INTEGER;
    idx_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO tbl_count FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO idx_count FROM pg_indexes WHERE schemaname = 'public';
    RAISE NOTICE '=== Migration Complete ===';
    RAISE NOTICE 'Tables: %', tbl_count;
    RAISE NOTICE 'Indexes: %', idx_count;
END $$;
