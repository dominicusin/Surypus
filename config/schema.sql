-- ============================================================
-- Surypus Complete Database Schema
-- PostgreSQL version
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- Reference Tables - Справочники
-- ============================================================

-- Currency (валюты)
CREATE TABLE IF NOT EXISTS currency (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,
    name VARCHAR(256) NOT NULL,
    symbol VARCHAR(8),
    rate NUMERIC(18,9) DEFAULT 1,
    is_base BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Currency rates (курсы валют)
CREATE TABLE IF NOT EXISTS currency_rate (
    id BIGSERIAL PRIMARY KEY,
    cur_id BIGINT NOT NULL REFERENCES currency(id),
    rate_type_id BIGINT NOT NULL,
    rel_cur_id BIGINT NOT NULL REFERENCES currency(id),
    dt DATE NOT NULL,
    rate NUMERIC(18,9) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cur_id, rate_type_id, rel_cur_id, dt)
);

-- Account sheet (план счетов)
CREATE TABLE IF NOT EXISTS acc_sheet (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Account (счета)
CREATE TABLE IF NOT EXISTS account (
    id BIGSERIAL PRIMARY KEY,
    sheet_id BIGINT NOT NULL REFERENCES acc_sheet(id),
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    parent_id BIGINT REFERENCES account(id),
    flags INTEGER DEFAULT 0,
    cur_id BIGINT REFERENCES currency(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sheet_id, code)
);

-- Operation kinds (виды операций)
CREATE TABLE IF NOT EXISTS op_kind (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    acc_sheet_id BIGINT REFERENCES acc_sheet(id),
    acc_sheet2_id BIGINT REFERENCES acc_sheet(id),
    link_op_id BIGINT REFERENCES op_kind(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Location types (типы местоположений)
CREATE TABLE IF NOT EXISTS loc_type (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES loc_type(id),
    flags INTEGER DEFAULT 0
);

-- Location (склады/адреса)
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

-- ============================================================
-- Goods - Товары
-- ============================================================

-- Goods (товары и группы)
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

-- Barcode (штрихкоды)
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

-- Goods class (классы товаров)
CREATE TABLE IF NOT EXISTS goods_class (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goods_class(id),
    flags INTEGER DEFAULT 0,
    prop_kind BIGINT,
    prop_grade BIGINT,
    prop_add BIGINT,
    prop_add2 BIGINT
);

-- ============================================================
-- Person - Контрагенты
-- ============================================================

-- Person (контрагенты)
CREATE TABLE IF NOT EXISTS person (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_person_name ON person USING gin(name gin_trgm_ops);

-- Person kinds (виды контрагентов)
CREATE TABLE IF NOT EXISTS person_kind (
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    kind_id BIGINT NOT NULL,
    name VARCHAR(256),
    PRIMARY KEY (person_id, kind_id)
);

-- Register (регистрации - ИНН, КПП и т.д.)
CREATE TABLE IF NOT EXISTS register (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    reg_type_id BIGINT NOT NULL,
    number VARCHAR(128) NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_register_person ON register(person_id);

-- ELink (электронные контакты - телефоны, email)
CREATE TABLE IF NOT EXISTS elink (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    kind_id BIGINT NOT NULL,
    address VARCHAR(256) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_elink_person ON elink(person_id);

-- ============================================================
-- Bill - Документы
-- ============================================================

-- Bill (документы)
CREATE TABLE IF NOT EXISTS bill (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    dt DATE NOT NULL,
    op_id BIGINT NOT NULL REFERENCES op_kind(id),
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

-- Bill lines (строки документов)
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

-- Amount (суммы документа)
CREATE TABLE IF NOT EXISTS amount (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id) ON DELETE CASCADE,
    amt_type_id SMALLINT NOT NULL,
    cur_id BIGINT NOT NULL DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(bill_id, amt_type_id, cur_id)
);

CREATE INDEX IF NOT EXISTS idx_amount_bill ON amount(bill_id);

-- Bill status (статусы документов)
CREATE TABLE IF NOT EXISTS bill_status (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INTEGER DEFAULT 0,
    color INTEGER DEFAULT 0
);

-- ============================================================
-- Inventory - Складской учёт
-- ============================================================

-- Stock (остатки)
CREATE TABLE IF NOT EXISTS stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL REFERENCES location(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    dt DATE,
    UNIQUE(goods_id, loc_id)
);

CREATE INDEX IF NOT EXISTS idx_stock_goods ON stock(goods_id);
CREATE INDEX IF NOT EXISTS idx_stock_loc ON stock(loc_id);

-- Lot (партии)
CREATE TABLE IF NOT EXISTS lot (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    dt DATE NOT NULL,
    expiry DATE,
    qtty NUMERIC(18,4) NOT NULL,
    rest NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    serial VARCHAR(64),
    country VARCHAR(64),
    gdoc VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lot_goods ON lot(goods_id);
CREATE INDEX IF NOT EXISTS idx_lot_bill ON lot(bill_id);

-- Goods movement (движения товаров)
CREATE TABLE IF NOT EXISTS gds_movement (
    id BIGSERIAL PRIMARY KEY,
    dt DATE NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL REFERENCES location(id),
    bill_id BIGINT REFERENCES bill(id),
    op_id BIGINT REFERENCES op_kind(id),
    qtty_in NUMERIC(18,4) DEFAULT 0,
    qtty_out NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_gds_movement_goods ON gds_movement(goods_id);
CREATE INDEX IF NOT EXISTS idx_gds_movement_loc ON gds_movement(loc_id);
CREATE INDEX IF NOT EXISTS idx_gds_movement_dt ON gds_movement(dt);

-- Transfer (перемещения)
CREATE TABLE IF NOT EXISTS transfer (
    id BIGSERIAL PRIMARY KEY,
    src_loc_id BIGINT NOT NULL REFERENCES location(id),
    dst_loc_id BIGINT NOT NULL REFERENCES location(id),
    goods_id BIGINT REFERENCES goods(id),
    qtty NUMERIC(18,4),
    price NUMERIC(18,4),
    status SMALLINT NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory (инвентаризация)
CREATE TABLE IF NOT EXISTS inventory (
    id BIGSERIAL PRIMARY KEY,
    loc_id BIGINT NOT NULL REFERENCES location(id),
    op_id BIGINT REFERENCES op_kind(id),
    status SMALLINT NOT NULL DEFAULT 0,
    memo TEXT,
    dt DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory lines
CREATE TABLE IF NOT EXISTS inventory_line (
    id BIGSERIAL PRIMARY KEY,
    inv_id BIGINT NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    lot_id BIGINT REFERENCES lot(id),
    fact_qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4),
    diff NUMERIC(18,4),
    cost NUMERIC(18,4)
);

-- Min stock / reorder point
CREATE TABLE IF NOT EXISTS min_stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL REFERENCES location(id),
    val NUMERIC(18,4) NOT NULL DEFAULT 0,
    UNIQUE(goods_id, loc_id)
);

CREATE TABLE IF NOT EXISTS reorder_point (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    loc_id BIGINT NOT NULL REFERENCES location(id),
    val NUMERIC(18,4) NOT NULL DEFAULT 0,
    UNIQUE(goods_id, loc_id)
);

-- ============================================================
-- Finance - Финансы
-- ============================================================

-- Transaction (проводки)
CREATE TABLE IF NOT EXISTS trans (
    id BIGSERIAL PRIMARY KEY,
    dt DATE NOT NULL,
    op_id BIGINT REFERENCES op_kind(id),
    object_id BIGINT,
    bill_id BIGINT REFERENCES bill(id),
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_trans_dt ON trans(dt);
CREATE INDEX IF NOT EXISTS idx_trans_bill ON trans(bill_id);

-- Transaction lines
CREATE TABLE IF NOT EXISTS trans_line (
    id BIGSERIAL PRIMARY KEY,
    trans_id BIGINT NOT NULL REFERENCES trans(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES account(id),
    debit NUMERIC(18,4) NOT NULL DEFAULT 0,
    credit NUMERIC(18,4) NOT NULL DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT NOT NULL DEFAULT 1,
    bill_id BIGINT REFERENCES bill(id)
);

CREATE INDEX IF NOT EXISTS idx_trans_line_trans ON trans_line(trans_id);
CREATE INDEX IF NOT EXISTS idx_trans_line_account ON trans_line(account_id);

-- Payment (платежи)
CREATE TABLE IF NOT EXISTS payment (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    loc_id BIGINT REFERENCES location(id),
    dt DATE NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    cur_id BIGINT NOT NULL DEFAULT 1,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Device - Оборудование
-- ============================================================

-- Device (оборудование)
CREATE TABLE IF NOT EXISTS device (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    loc_id BIGINT REFERENCES location(id),
    ip VARCHAR(64),
    port INTEGER,
    config JSONB,
    flags INTEGER DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    serial VARCHAR(64),
    last_activity TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_device_type ON device(type);
CREATE INDEX IF NOT EXISTS idx_device_loc ON device(loc_id);

-- Cash register (кассовый аппарат)
CREATE TABLE IF NOT EXISTS cash_register (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES device(id),
    session_id BIGINT,
    fiscal_mode BOOLEAN DEFAULT FALSE,
    rn VARCHAR(64),
    kkm_number VARCHAR(64),
    last_check DATE
);

-- Cash session (кассовая смена)
CREATE TABLE IF NOT EXISTS cash_session (
    id BIGSERIAL PRIMARY KEY,
    register_id BIGINT NOT NULL REFERENCES cash_register(id),
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cash_session_register ON cash_session(register_id);
CREATE INDEX IF NOT EXISTS idx_cash_session_dt ON cash_session(dt);

-- Cash operations (операции с наличными)
CREATE TABLE IF NOT EXISTS cash_operation (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES cash_session(id),
    op_type SMALLINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    reason TEXT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Receipt (чеки)
CREATE TABLE IF NOT EXISTS receipt (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES cash_session(id),
    bill_id BIGINT REFERENCES bill(id),
    check_no INTEGER NOT NULL,
    total NUMERIC(18,4) NOT NULL,
    discount NUMERIC(18,4) DEFAULT 0,
    tax NUMERIC(18,4) DEFAULT 0,
    payment_type SMALLINT DEFAULT 1,
    fiscal_no BIGINT,
    fiscal_sign VARCHAR(64),
    is_fiscal BOOLEAN DEFAULT FALSE,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_receipt_session ON receipt(session_id);

-- Scale PLU (весы)
CREATE TABLE IF NOT EXISTS scale (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES device(id),
    plu_count INTEGER DEFAULT 1000,
    max_weight NUMERIC(18,4),
    min_weight NUMERIC(18,4),
    accuracy INTEGER DEFAULT 1,
    proto VARCHAR(32)
);

CREATE TABLE IF NOT EXISTS scale_plu (
    id BIGSERIAL PRIMARY KEY,
    scale_id BIGINT NOT NULL REFERENCES scale(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    plu INTEGER NOT NULL,
    price NUMERIC(18,4),
    tara NUMERIC(18,4) DEFAULT 0,
    unit SMALLINT DEFAULT 0,
    UNIQUE(scale_id, goods_id),
    UNIQUE(scale_id, plu)
);

-- POS terminal (эквайринг)
CREATE TABLE IF NOT EXISTS pos_terminal (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES device(id),
    acquirer_id BIGINT,
    merchant_id VARCHAR(64),
    terminal_id VARCHAR(64),
    proto VARCHAR(32)
);

-- POS transactions
CREATE TABLE IF NOT EXISTS pos_transaction (
    id BIGSERIAL PRIMARY KEY,
    terminal_id BIGINT NOT NULL REFERENCES pos_terminal(id),
    bill_id BIGINT REFERENCES bill(id),
    rrn VARCHAR(12),
    auth_code VARCHAR(6),
    amount NUMERIC(18,4) NOT NULL,
    card_num VARCHAR(20),
    status SMALLINT NOT NULL DEFAULT 0,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancel_dt TIMESTAMP
);

-- ============================================================
-- Associations - Связи
-- ============================================================

-- Object associations (группы документов, связи)
CREATE TABLE IF NOT EXISTS assoc (
    id BIGSERIAL PRIMARY KEY,
    assc_type BIGINT NOT NULL,
    prmr_obj_id BIGINT NOT NULL,
    scnd_obj_id BIGINT NOT NULL,
    inner_num INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(assc_type, prmr_obj_id, scnd_obj_id)
);

CREATE INDEX IF NOT EXISTS idx_assoc_type ON assoc(assc_type);
CREATE INDEX IF NOT EXISTS idx_assoc_prmr ON assoc(prmr_obj_id);
CREATE INDEX IF NOT EXISTS idx_assoc_scnd ON assoc(scnd_obj_id);

-- ============================================================
-- Default Data - Начальные данные
-- ============================================================

-- Insert base currency
INSERT INTO currency (code, name, symbol, rate, is_base) 
VALUES ('RUB', 'Российский рубль', '₽', 1, TRUE)
ON CONFLICT (code) DO NOTHING;

-- Insert main organization
INSERT INTO person (name, flags, status)
VALUES ('Основная организация', 0, 0)
ON CONFLICT DO NOTHING;

-- Insert main warehouse
INSERT INTO location (name, type, flags)
VALUES ('Основной склад', 1, 2)
ON CONFLICT DO NOTHING;

-- Insert account sheets
INSERT INTO acc_sheet (name, type, flags) VALUES
    ('Основной план', 0, 0),
    ('Управленческий', 1, 0),
    ('Налоговый', 2, 0)
ON CONFLICT DO NOTHING;

-- Insert main accounts
INSERT INTO account (sheet_id, name, code, type, flags) VALUES
    (1, 'Касса', '50', 1, 16),
    (1, 'Касса в рублях', '50.1', 1, 16),
    (1, 'Расчётный счёт', '51', 1, 8),
    (1, 'Расчёты с поставщиками', '60', 3, 0),
    (1, 'Расчёты с покупателями', '62', 3, 0),
    (1, 'Товары', '41', 1, 0),
    (1, 'Товары на складе', '41.1', 1, 0),
    (1, 'НДС по приобретённым', '19', 2, 0),
    (1, 'НДС по реализации', '68.2', 2, 0),
    (1, 'Прибыль', '99', 2, 0)
ON CONFLICT DO NOTHING;

-- Insert operation types
INSERT INTO op_kind (name, type, flags, acc_sheet_id) VALUES
    ('Приход товара', 1, 0, 1),
    ('Расход товара', 2, 0, 1),
    ('Возврат поставщику', 3, 0, 1),
    ('Возврат покупателя', 4, 0, 1),
    ('Инвентаризация', 5, 0, 1),
    ('Списание', 6, 0, 1),
    ('Перемещение', 7, 0, 1),
    ('Заказ', 8, 0, 1),
    ('Оплата', 9, 0, 1),
    ('Начисление', 10, 0, 1)
ON CONFLICT DO NOTHING;

-- ============================================================
-- Extended Tables - Расширенные таблицы
-- ============================================================

-- Unit (единицы измерения)
CREATE TABLE IF NOT EXISTS unit (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    code VARCHAR(8),
    is_pharmaceutical BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Price Lists (прайс-листы)
CREATE TABLE IF NOT EXISTS price_list (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    valid_from DATE,
    valid_to DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS price_list_goods (
    id BIGSERIAL PRIMARY KEY,
    price_list_id BIGINT NOT NULL REFERENCES price_list(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price NUMERIC(18,4) NOT NULL,
    discount NUMERIC(6,2) DEFAULT 0,
    min_qtty NUMERIC(18,4) DEFAULT 1,
    start_dt DATE,
    end_dt DATE,
    UNIQUE(price_list_id, goods_id, start_dt)
);

-- Goods Groups (группы товаров)
CREATE TABLE IF NOT EXISTS goods_group (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goods_group(id),
    code VARCHAR(16),
    description TEXT
);

-- Goods Alternatives (альтернативные товары)
CREATE TABLE IF NOT EXISTS goods_alt (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    alt_goods_id BIGINT NOT NULL REFERENCES goods(id),
    priority INTEGER DEFAULT 0
);

-- Composite Structure (спецификации / BOM)
CREATE TABLE IF NOT EXISTS composite_struct (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    component_goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    yield_percent NUMERIC(6,2)
);

-- Tech Cards (технологические карты)
CREATE TABLE IF NOT EXISTS tech_card (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT FALSE,
    output_qtty NUMERIC(18,4) NOT NULL,
    output_unit_id BIGINT REFERENCES unit(id),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tech_card_material (
    id BIGSERIAL PRIMARY KEY,
    tech_card_id BIGINT NOT NULL REFERENCES tech_card(id),
    material_goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL,
    is_input BOOLEAN DEFAULT TRUE,
    yield_percent NUMERIC(6,2),
    order_num INTEGER DEFAULT 0
);

-- Production Orders (производственные заказы)
CREATE TABLE IF NOT EXISTS production_order (
    id BIGSERIAL PRIMARY KEY,
    order_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL,
    loc_id BIGINT NOT NULL REFERENCES location(id),
    work_center_id BIGINT,
    due_date DATE,
    priority SMALLINT DEFAULT 1,
    status SMALLINT DEFAULT 1,
    dt DATE NOT NULL,
    start_dt TIMESTAMP,
    complete_dt TIMESTAMP,
    cancel_dt TIMESTAMP,
    cancel_reason TEXT,
    actual_qtty NUMERIC(18,4),
    notes TEXT
);

-- Work Centers (рабочие центры)
CREATE TABLE IF NOT EXISTS work_center (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    capacity NUMERIC(18,4),
    efficiency NUMERIC(6,2) DEFAULT 100,
    status SMALLINT DEFAULT 1,
    loc_id BIGINT REFERENCES location(id),
    hourly_rate NUMERIC(18,4)
);

-- Budget (бюджетирование)
CREATE TABLE IF NOT EXISTS budget_version (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    year INTEGER NOT NULL,
    period_type SMALLINT NOT NULL,
    base_version_id BIGINT REFERENCES budget_version(id),
    status SMALLINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS budget_item (
    id BIGSERIAL PRIMARY KEY,
    version_id BIGINT NOT NULL REFERENCES budget_version(id),
    account_id BIGINT NOT NULL REFERENCES account(id),
    period_no INTEGER NOT NULL,
    plan_amount NUMERIC(18,4) DEFAULT 0,
    notes TEXT,
    UNIQUE(version_id, account_id, period_no)
);

-- Journal Entries (бухгалтерский журнал)
CREATE TABLE IF NOT EXISTS journal_entry (
    id BIGSERIAL PRIMARY KEY,
    dt DATE NOT NULL,
    doc_type SMALLINT,
    doc_id BIGINT,
    memo TEXT,
    total_debit NUMERIC(18,4) NOT NULL,
    total_credit NUMERIC(18,4) NOT NULL,
    status SMALLINT DEFAULT 1,
    reverse_of BIGINT REFERENCES journal_entry(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    posted_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS journal_line (
    id BIGSERIAL PRIMARY KEY,
    entry_id BIGINT NOT NULL REFERENCES journal_entry(id),
    account_id BIGINT NOT NULL REFERENCES account(id),
    debit NUMERIC(18,4) DEFAULT 0,
    credit NUMERIC(18,4) DEFAULT 0,
    amount NUMERIC(18,4) DEFAULT 0,
    cur_id BIGINT DEFAULT 1,
    analytic_id BIGINT
);

-- Operation Account Mapping (автопроводки)
CREATE TABLE IF NOT EXISTS op_account (
    id BIGSERIAL PRIMARY KEY,
    op_id BIGINT NOT NULL,
    op_type SMALLINT NOT NULL,
    account_id BIGINT NOT NULL,
    UNIQUE(op_id, op_type)
);

-- Recurring Template (регулярные проводки)
CREATE TABLE IF NOT EXISTS recurring_template (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    debit_account_id BIGINT NOT NULL,
    credit_account_id BIGINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    frequency VARCHAR(20) NOT NULL,
    next_run_date DATE NOT NULL,
    last_run_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

-- HR Extended (расширенные HR)
CREATE TABLE IF NOT EXISTS staffing_table (
    id BIGSERIAL PRIMARY KEY,
    department_id BIGINT NOT NULL,
    position_id BIGINT NOT NULL,
    loc_id BIGINT REFERENCES location(id),
    count INTEGER NOT NULL DEFAULT 1,
    salary_min NUMERIC(18,4),
    salary_max NUMERIC(18,4),
    effective_date DATE NOT NULL,
    status SMALLINT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS salary_addition (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    addition_type SMALLINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    period DATE NOT NULL,
    reason TEXT
);

CREATE TABLE IF NOT EXISTS salary_deduction (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    deduction_type SMALLINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    period DATE NOT NULL,
    reason TEXT
);

CREATE TABLE IF NOT EXISTS absence (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days INTEGER NOT NULL,
    absence_type SMALLINT NOT NULL,
    reason TEXT,
    status SMALLINT DEFAULT 1,
    approved_by BIGINT,
    approved_at TIMESTAMP,
    approver_comment TEXT
);

CREATE TABLE IF NOT EXISTS absence_allowance (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    absence_type SMALLINT NOT NULL,
    year INTEGER NOT NULL,
    days INTEGER NOT NULL DEFAULT 28
);

CREATE TABLE IF NOT EXISTS performance_review (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    reviewer_id BIGINT NOT NULL,
    review_period VARCHAR(20) NOT NULL,
    review_date DATE NOT NULL,
    overall_rating SMALLINT,
    recommendations TEXT,
    status SMALLINT DEFAULT 1,
    completed_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS performance_rating (
    id BIGSERIAL PRIMARY KEY,
    review_id BIGINT NOT NULL,
    criterion_id BIGINT NOT NULL,
    rating SMALLINT NOT NULL,
    comment TEXT
);

CREATE TABLE IF NOT EXISTS performance_criterion (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    weight NUMERIC(3,2) DEFAULT 1.0
);

-- EGAIS Extended (ЕГАИС)
CREATE TABLE IF NOT EXISTS egais_waybill_position (
    id BIGSERIAL PRIMARY KEY,
    waybill_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    quantity NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4),
    mark_code VARCHAR(68)
);

CREATE TABLE IF NOT EXISTS egais_balance (
    id BIGSERIAL PRIMARY KEY,
    org_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    quantity NUMERIC(18,4) NOT NULL,
    unit VARCHAR(16) DEFAULT '0',
    dt DATE DEFAULT CURRENT_DATE
);

ALTER TABLE egais_request ADD COLUMN IF NOT EXISTS reply_id BIGINT;
ALTER TABLE egais_request ADD COLUMN IF NOT EXISTS result TEXT;

ALTER TABLE egais_waybill ADD COLUMN IF NOT EXISTS sender_id BIGINT;
ALTER TABLE egais_waybill ADD COLUMN IF NOT EXISTS receiver_id BIGINT;
ALTER TABLE egais_waybill ADD COLUMN IF NOT EXISTS reply_content TEXT;
ALTER TABLE egais_waybill ADD COLUMN IF NOT EXISTS request_id BIGINT;

ALTER TABLE egais_mark ADD COLUMN IF NOT EXISTS waybill_id BIGINT;
ALTER TABLE egais_mark ADD COLUMN IF NOT EXISTS box_number VARCHAR(32);

ALTER TABLE egais_inventory ADD COLUMN IF NOT EXISTS loc_id BIGINT;
ALTER TABLE egais_inventory ADD COLUMN IF NOT EXISTS request_id BIGINT;
ALTER TABLE egais_inventory ADD COLUMN IF NOT EXISTS reply_id BIGINT;
ALTER TABLE egais_inventory ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;

-- EDI Extended
ALTER TABLE edi_message ADD COLUMN IF NOT EXISTS sender_id BIGINT;
ALTER TABLE edi_message ADD COLUMN IF NOT EXISTS receiver_id BIGINT;
ALTER TABLE edi_message ADD COLUMN IF NOT EXISTS reference VARCHAR(64);
ALTER TABLE edi_message ADD COLUMN IF NOT EXISTS msg_no VARCHAR(20);
ALTER TABLE edi_message ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP;

-- CRM
CREATE TABLE IF NOT EXISTS crm_interaction (
    id BIGSERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL,
    interaction_type SMALLINT NOT NULL,
    subject VARCHAR(256) NOT NULL,
    description TEXT,
    user_id BIGINT NOT NULL,
    due_date DATE,
    status SMALLINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS crm_opportunity (
    id BIGSERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL,
    stage_id BIGINT NOT NULL,
    owner_id BIGINT NOT NULL,
    expected_amount NUMERIC(18,4),
    probability NUMERIC(5,2) DEFAULT 50,
    close_date DATE,
    status SMALLINT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS crm_pipeline_stage (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    order_num INTEGER NOT NULL,
    probability NUMERIC(5,2)
);

-- Loan/Credit
CREATE TABLE IF NOT EXISTS loan (
    id BIGSERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    interest_rate NUMERIC(6,2) NOT NULL,
    term_months INTEGER NOT NULL,
    monthly_payment NUMERIC(18,4),
    start_date DATE NOT NULL,
    loan_type SMALLINT DEFAULT 1,
    status SMALLINT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS loan_payment (
    id BIGSERIAL PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    dt DATE NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    principal_part NUMERIC(18,4),
    interest_part NUMERIC(18,4)
);

-- Warehousing
CREATE TABLE IF NOT EXISTS picking_task (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    picker_id BIGINT,
    priority SMALLINT DEFAULT 1,
    status SMALLINT DEFAULT 1,
    dt DATE NOT NULL,
    completed_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS picking_item (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL,
    qtty_needed NUMERIC(18,4),
    picked_qtty NUMERIC(18,4),
    picked_at TIMESTAMP
);

-- QC
CREATE TABLE IF NOT EXISTS qc_inspection (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT,
    inspector_id BIGINT NOT NULL,
    inspection_type SMALLINT NOT NULL,
    template_id BIGINT,
    overall_result SMALLINT,
    notes TEXT,
    status SMALLINT DEFAULT 1,
    dt DATE NOT NULL,
    completed_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS qc_check_point (
    id BIGSERIAL PRIMARY KEY,
    inspection_id BIGINT NOT NULL,
    check_point_id BIGINT NOT NULL,
    status SMALLINT DEFAULT 0,
    value TEXT,
    comment TEXT,
    checked_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS qc_template (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    inspection_type SMALLINT NOT NULL
);

CREATE TABLE IF NOT EXISTS qc_template_point (
    id BIGSERIAL PRIMARY KEY,
    template_id BIGINT NOT NULL,
    name VARCHAR(256) NOT NULL,
    check_method TEXT,
    is_critical BOOLEAN DEFAULT FALSE
);

-- Extended Location (warehouse zones)
ALTER TABLE location ADD COLUMN IF NOT EXISTS zone VARCHAR(8);
ALTER TABLE location ADD COLUMN IF NOT EXISTS aisle INTEGER;
ALTER TABLE location ADD COLUMN IF NOT EXISTS shelf INTEGER;
ALTER TABLE location ADD COLUMN IF NOT EXISTS bin_location VARCHAR(16);

-- Extended Goods
ALTER TABLE goods ADD COLUMN IF NOT EXISTS is_phantom BOOLEAN DEFAULT FALSE;
ALTER TABLE goods ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- Extended Time Entry
ALTER TABLE time_entry ADD COLUMN IF NOT EXISTS time_in TIME;
ALTER TABLE time_entry ADD COLUMN IF NOT EXISTS time_out TIME;

-- ============================================================
-- Indexes - Индексы
-- ============================================================

-- Price Lists
CREATE INDEX IF NOT EXISTS idx_price_list_goods_price_list ON price_list_goods(price_list_id);
CREATE INDEX IF NOT EXISTS idx_price_list_goods_goods ON price_list_goods(goods_id);
CREATE INDEX IF NOT EXISTS idx_goods_group_parent ON goods_group(parent_id);
CREATE INDEX IF NOT EXISTS idx_goods_alt_goods ON goods_alt(goods_id);
CREATE INDEX IF NOT EXISTS idx_composite_struct_goods ON composite_struct(goods_id);
CREATE INDEX IF NOT EXISTS idx_tech_card_goods ON tech_card(goods_id, is_active);
CREATE INDEX IF NOT EXISTS idx_tech_card_material_card ON tech_card_material(tech_card_id);
CREATE INDEX IF NOT EXISTS idx_production_order_status ON production_order(status);
CREATE INDEX IF NOT EXISTS idx_production_order_due_date ON production_order(due_date);
CREATE INDEX IF NOT EXISTS idx_budget_item_version ON budget_item(version_id);
CREATE INDEX IF NOT EXISTS idx_budget_item_account ON budget_item(account_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_dt ON journal_entry(dt);
CREATE INDEX IF NOT EXISTS idx_journal_entry_status ON journal_entry(status);
CREATE INDEX IF NOT EXISTS idx_journal_line_entry ON journal_line(entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_line_account ON journal_line(account_id);
CREATE INDEX IF NOT EXISTS idx_staffing_department ON staffing_table(department_id);
CREATE INDEX IF NOT EXISTS idx_salary_addition_employee ON salary_addition(employee_id, period);
CREATE INDEX IF NOT EXISTS idx_absence_employee ON absence(employee_id, start_date);
CREATE INDEX IF NOT EXISTS idx_performance_review_employee ON performance_review(employee_id);
CREATE INDEX IF NOT EXISTS idx_egais_waybill_sender ON egais_waybill(sender_id);
CREATE INDEX IF NOT EXISTS idx_egais_waybill_receiver ON egais_waybill(receiver_id);
CREATE INDEX IF NOT EXISTS idx_egais_mark_code ON egais_mark(code);
CREATE INDEX IF NOT EXISTS idx_egais_balance_org ON egais_balance(org_id);
CREATE INDEX IF NOT EXISTS idx_edi_message_no ON edi_message(msg_no);
CREATE INDEX IF NOT EXISTS idx_edi_message_sender ON edi_message(sender_id);
CREATE INDEX IF NOT EXISTS idx_edi_message_receiver ON edi_message(receiver_id);
CREATE INDEX IF NOT EXISTS idx_crm_interaction_client ON crm_interaction(client_id);
CREATE INDEX IF NOT EXISTS idx_crm_opportunity_client ON crm_opportunity(client_id);
CREATE INDEX IF NOT EXISTS idx_loan_client ON loan(client_id);
CREATE INDEX IF NOT EXISTS idx_picking_task_order ON picking_task(order_id);
CREATE INDEX IF NOT EXISTS idx_qc_inspection_bill ON qc_inspection(bill_id);
