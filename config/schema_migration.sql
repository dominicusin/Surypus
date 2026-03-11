-- ============================================================
-- Additional Tables - Complete the migration
-- Add to schema_optimized.sql
-- ============================================================

-- ============================================================
-- Unit (Единицы измерения)
-- ============================================================
CREATE TABLE IF NOT EXISTS unit (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    code VARCHAR(8),
    is_pharmaceutical BOOLEAN DEFAULT FALSE,
    ratio NUMERIC(18,8) DEFAULT 1,
    dim_length NUMERIC(8,2),
    dim_width NUMERIC(8,2),
    dim_height NUMERIC(8,2),
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_unit_code ON unit(code) WHERE code IS NOT NULL;

-- ============================================================
-- Price Lists
-- ============================================================
CREATE TABLE IF NOT EXISTS price_list (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    valid_from DATE,
    valid_to DATE,
    flags INTEGER DEFAULT 0,
    is_auto_update BOOLEAN DEFAULT FALSE,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_price_list_valid ON price_list(valid_from, valid_to);

CREATE TABLE IF NOT EXISTS price_list_goods (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    price_list_id BIGINT NOT NULL REFERENCES price_list(id) ON DELETE CASCADE,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    price NUMERIC(18,4) NOT NULL,
    discount_percent NUMERIC(6,2) DEFAULT 0,
    min_qtty NUMERIC(18,4) DEFAULT 1,
    start_dt DATE,
    end_dt DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(price_list_id, goods_id, start_dt)
);

CREATE INDEX idx_plg_list ON price_list_goods(price_list_id);
CREATE INDEX idx_plg_goods ON price_list_goods(goods_id);

-- ============================================================
-- Tax Tables
-- ============================================================
CREATE TABLE IF NOT EXISTS tax_group (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    rate NUMERIC(6,2) NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vat_rate (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    percent NUMERIC(6,2) NOT NULL,
    flags INTEGER DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tax_invoice (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    dt DATE NOT NULL,
    number VARCHAR(16) NOT NULL,
    seller_id BIGINT REFERENCES person(id),
    buyer_id BIGINT REFERENCES person(id),
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number)
);

CREATE INDEX idx_tax_invoice_dt ON tax_invoice(dt);
CREATE INDEX idx_tax_invoice_seller ON tax_invoice(seller_id);
CREATE INDEX idx_tax_invoice_buyer ON tax_invoice(buyer_id);

-- ============================================================
-- Security
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    login VARCHAR(64) NOT NULL UNIQUE,
    password VARCHAR(128) NOT NULL,
    email VARCHAR(128),
    phone VARCHAR(32),
    group_id BIGINT,
    main_org_id BIGINT,
    flags INTEGER DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_login ON users(login);
CREATE INDEX idx_users_group ON users(group_id) WHERE group_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS user_group (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS session (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_dt TIMESTAMPTZ,
    ip VARCHAR(64),
    token VARCHAR(64) NOT NULL UNIQUE,
    status SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0
);

CREATE INDEX idx_session_token ON session(token);
CREATE INDEX idx_session_user ON session(user_id);

-- ============================================================
-- EDI/ЕГАИС
-- ============================================================
CREATE TABLE IF NOT EXISTS edi_partner (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    gln VARCHAR(20) NOT NULL UNIQUE,
    inn VARCHAR(12) NOT NULL,
    kpp VARCHAR(9),
    name VARCHAR(256) NOT NULL,
    partner_type SMALLINT NOT NULL DEFAULT 0,
    edi_id VARCHAR(64),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_edi_partner_inn ON edi_partner(inn) WHERE inn IS NOT NULL;

CREATE TABLE IF NOT EXISTS edi_message (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    msg_type SMALLINT NOT NULL,
    direction SMALLINT NOT NULL,
    partner_id BIGINT REFERENCES edi_partner(id) ON DELETE SET NULL,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    content TEXT,
    status SMALLINT NOT NULL DEFAULT 0,
    error TEXT,
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX idx_edi_message_dt ON edi_message(dt);
CREATE INDEX idx_edi_message_status ON edi_message(status);

CREATE TABLE IF NOT EXISTS egais_mark (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    code VARCHAR(68) NOT NULL UNIQUE,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE RESTRICT,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    box_id BIGINT,
    status SMALLINT NOT NULL DEFAULT 0,
    scan_dt TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_egais_mark_goods ON egais_mark(goods_id);
CREATE INDEX idx_egais_mark_bill ON egais_mark(bill_id) WHERE bill_id IS NOT NULL;
CREATE INDEX idx_egais_mark_status ON egais_mark(status);

-- ============================================================
-- HR Tables
-- ============================================================
CREATE TABLE IF NOT EXISTS department (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES department(id) ON DELETE SET NULL,
    manager_id BIGINT,
    head_count INTEGER,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dept_parent ON department(parent_id);

CREATE TABLE IF NOT EXISTS position (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    department_id BIGINT REFERENCES department(id) ON DELETE SET NULL,
    salary_min NUMERIC(18,4),
    salary_max NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    sort_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_position_dept ON position(department_id);

CREATE TABLE IF NOT EXISTS employee (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    department_id BIGINT REFERENCES department(id) ON DELETE SET NULL,
    position_id BIGINT REFERENCES position(id) ON DELETE SET NULL,
    hire_date DATE NOT NULL,
    fire_date DATE,
    salary NUMERIC(18,4),
    tab_no VARCHAR(16),
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_employee_tab ON employee(tab_no) WHERE tab_no IS NOT NULL;
CREATE INDEX idx_employee_person ON employee(person_id);
CREATE INDEX idx_employee_dept ON employee(department_id);
CREATE INDEX idx_employee_status ON employee(status);

-- ============================================================
-- Devices
-- ============================================================
CREATE TABLE IF NOT EXISTS device (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    loc_id BIGINT REFERENCES location(id) ON DELETE SET NULL,
    ip VARCHAR(64),
    port INTEGER,
    config JSONB,
    flags INTEGER DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    serial VARCHAR(64),
    last_activity TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_device_type ON device(type);
CREATE INDEX idx_device_loc ON device(loc_id) WHERE loc_id IS NOT NULL;
CREATE INDEX idx_device_status ON device(status);

CREATE TABLE IF NOT EXISTS cash_session (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES device(id) ON DELETE CASCADE,
    session_no INTEGER NOT NULL,
    cashier_id BIGINT NOT NULL,
    dt DATE NOT NULL,
    closed_dt DATE,
    status SMALLINT NOT NULL DEFAULT 0,
    initial_cash NUMERIC(18,4) DEFAULT 0,
    final_cash NUMERIC(18,4),
    income NUMERIC(18,4) DEFAULT 0,
    expense NUMERIC(18,4) DEFAULT 0,
    check_count INTEGER DEFAULT 0,
    void_count INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cash_session_device ON cash_session(device_id);
CREATE INDEX idx_cash_session_dt ON cash_session(dt);

-- ============================================================
-- Transfer
-- ============================================================
CREATE TABLE IF NOT EXISTS transfer (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    src_loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
    dst_loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
    goods_id BIGINT REFERENCES goods(id) ON DELETE SET NULL,
    qtty NUMERIC(18,4),
    price NUMERIC(18,4),
    status SMALLINT NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    shipped_dt DATE,
    received_dt DATE,
    waybill_no VARCHAR(32),
    memo TEXT,
    bill_id BIGINT REFERENCES bill(id) ON DELETE SET NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transfer_src ON transfer(src_loc_id);
CREATE INDEX idx_transfer_dst ON transfer(dst_loc_id);
CREATE INDEX idx_transfer_goods ON transfer(goods_id) WHERE goods_id IS NOT NULL;
CREATE INDEX idx_transfer_dt ON transfer(dt);
CREATE INDEX idx_transfer_status ON transfer(status);

-- ============================================================
-- Inventory
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
    op_id BIGINT REFERENCES op_kind(id) ON DELETE SET NULL,
    inv_no VARCHAR(16),
    dt DATE NOT NULL,
    status SMALLINT DEFAULT 0,
    memo TEXT,
    total_diff NUMERIC(18,4) DEFAULT 0,
    total_amount NUMERIC(18,4),
    approved_by BIGINT,
    approved_dt TIMESTAMPTZ,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_inventory_loc ON inventory(loc_id);
CREATE INDEX idx_inventory_dt ON inventory(dt);
CREATE INDEX idx_inventory_status ON inventory(status);

CREATE TABLE IF NOT EXISTS inventory_line (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    inv_id BIGINT NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE RESTRICT,
    lot_id BIGINT REFERENCES lot(id) ON DELETE SET NULL,
    fact_qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4),
    diff NUMERIC(18,4),
    cost NUMERIC(18,4)
);

CREATE INDEX idx_inv_line_inv ON inventory_line(inv_id);
CREATE INDEX idx_inv_line_goods ON inventory_line(goods_id);

-- ============================================================
-- Associations
-- ============================================================
CREATE TABLE IF NOT EXISTS assoc (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    assc_type BIGINT NOT NULL,
    prmr_obj_id BIGINT NOT NULL,
    scnd_obj_id BIGINT NOT NULL,
    inner_num INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(assc_type, prmr_obj_id, scnd_obj_id)
);

CREATE INDEX idx_assoc_type ON assoc(assc_type);
CREATE INDEX idx_assoc_prmr ON assoc(prmr_obj_id);
CREATE INDEX idx_assoc_scnd ON assoc(scnd_obj_id);

-- ============================================================
-- Composite Structure (BOM)
-- ============================================================
CREATE TABLE IF NOT EXISTS composite_struct (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    component_goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    yield_percent NUMERIC(6,2),
    is_optional BOOLEAN DEFAULT FALSE,
    seq_no INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(goods_id, component_goods_id)
);

CREATE INDEX idx_composite_goods ON composite_struct(goods_id);
CREATE INDEX idx_composite_component ON composite_struct(component_goods_id);

-- ============================================================
-- Production
-- ============================================================
CREATE TABLE IF NOT EXISTS production_order (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    order_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE RESTRICT,
    qtty NUMERIC(18,4) NOT NULL,
    loc_id BIGINT NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
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

CREATE INDEX idx_prod_order_status ON production_order(status);
CREATE INDEX idx_prod_order_due ON production_order(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX idx_prod_order_goods ON production_order(goods_id);

CREATE TABLE IF NOT EXISTS work_center (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    capacity NUMERIC(18,4),
    efficiency NUMERIC(6,2) DEFAULT 100,
    status SMALLINT DEFAULT 1,
    loc_id BIGINT REFERENCES location(id) ON DELETE SET NULL,
    hourly_rate NUMERIC(18,4),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- Budget
-- ============================================================
CREATE TABLE IF NOT EXISTS budget_version (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    year INTEGER NOT NULL,
    period_type SMALLINT NOT NULL,
    base_version_id BIGINT REFERENCES budget_version(id) ON DELETE SET NULL,
    status SMALLINT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    approved_at TIMESTAMPTZ
);

CREATE INDEX idx_budget_version_year ON budget_version(year);

CREATE TABLE IF NOT EXISTS budget_item (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    version_id BIGINT NOT NULL REFERENCES budget_version(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES account(id) ON DELETE RESTRICT,
    period_no INTEGER NOT NULL,
    plan_amount NUMERIC(18,4) DEFAULT 0,
    notes TEXT,
    UNIQUE(version_id, account_id, period_no)
);

CREATE INDEX idx_budget_item_version ON budget_item(version_id);
CREATE INDEX idx_budget_item_account ON budget_item(account_id);

-- ============================================================
-- Journal Entry
-- ============================================================
CREATE TABLE IF NOT EXISTS journal_entry (
    id BIGINT DEFAULT nextval('global_id_seq') PRIMARY KEY,
    dt DATE NOT NULL,
    doc_type SMALLINT,
    doc_id BIGINT,
    memo TEXT,
    total_debit NUMERIC(18,4) NOT NULL,
    total_credit NUMERIC(18,4) NOT NULL,
    status SMALLINT DEFAULT 1,
    reverse_of BIGINT REFERENCES journal_entry(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    posted_at TIMESTAMPTZ
);

CREATE INDEX idx_journal_entry_dt ON journal_entry(dt);
CREATE INDEX idx_journal_entry_status ON journal_entry(status);
CREATE INDEX idx_journal_entry_doc ON journal_entry(doc_type, doc_id) WHERE doc_type IS NOT NULL;

-- ============================================================
-- Insert Default Data
-- ============================================================

INSERT INTO unit (name, code, ratio, sort_order) VALUES
    ('шт', 'pc', 1, 1),
    ('кг', 'kg', 1, 2),
    ('л', 'l', 1, 3),
    ('м', 'm', 1, 4),
    ('м²', 'm2', 1, 5),
    ('упак', 'pack', 1, 6)
ON CONFLICT DO NOTHING;

INSERT INTO tax_group (name, rate, sort_order) VALUES
    ('Без НДС', 0, 1),
    ('НДС 10%', 10, 2),
    ('НДС 20%', 20, 3)
ON CONFLICT DO NOTHING;

INSERT INTO vat_rate (name, percent, valid_from) VALUES
    ('Без НДС', 0, '2024-01-01'),
    ('НДС 10%', 10, '2024-01-01'),
    ('НДС 20%', 20, '2024-01-01')
ON CONFLICT DO NOTHING;

INSERT INTO user_group (name, description) VALUES
    ('Администраторы', 'Полный доступ'),
    ('Менеджеры', 'Управление документами'),
    ('Кассиры', 'Кассовые операции'),
    ('Кладовщики', 'Складские операции')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Final Statistics
-- ============================================================
DO $$
DECLARE
    tbl_count INTEGER;
    idx_count INTEGER;
    part_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO tbl_count FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO idx_count FROM pg_indexes WHERE schemaname = 'public';
    SELECT COUNT(*) INTO part_count FROM pg_tables WHERE tablename LIKE '%_2024' OR tablename LIKE '%_2025' OR tablename LIKE '%_2026';
    
    RAISE NOTICE 'Migration complete: % tables, % indexes, % partitions', tbl_count, idx_count, part_count;
END $$;
