-- =============================================================================
-- Surypus - BTR Tables Mapping
-- All 90 tables from sample/*.BTR
-- Mapped to PostgreSQL with proper types and relationships
-- =============================================================================

-- ============================================================
-- Account Relations (acctrel)
-- Связи между счетами (корреспонденция)
-- ============================================================
CREATE TABLE IF NOT EXISTS acctrel (
    id BIGSERIAL PRIMARY KEY,
    acc_id BIGINT NOT NULL REFERENCES account(id),
    correl_acc_id BIGINT NOT NULL REFERENCES account(id),
    op_kind_id BIGINT REFERENCES op_kind(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_acctrel_acc ON acctrel(acc_id);
CREATE INDEX IF NOT EXISTS idx_acctrel_correl ON acctrel(correl_acc_id);

-- ============================================================
-- Account Turns (accturn)
-- Обороты по счетам
-- ============================================================
CREATE TABLE IF NOT EXISTS accturn (
    id BIGSERIAL PRIMARY KEY,
    acc_id BIGINT NOT NULL REFERENCES account(id),
    op_kind_id BIGINT REFERENCES op_kind(id),
    dt DATE NOT NULL,
    debit NUMERIC(18,4) NOT NULL DEFAULT 0,
    credit NUMERIC(18,4) NOT NULL DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT DEFAULT 1,
    c_rate NUMERIC(18,9) DEFAULT 1,
    bill_id BIGINT REFERENCES bill(id),
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_accturn_acc ON accturn(acc_id);
CREATE INDEX IF NOT EXISTS idx_accturn_dt ON accturn(dt);
CREATE INDEX IF NOT EXISTS idx_accturn_bill ON accturn(bill_id);

-- ============================================================
-- Advance Bill Items (advbitem)
-- Авансовые платежи по документам
-- ============================================================
CREATE TABLE IF NOT EXISTS advbitem (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    advance_bill_id BIGINT REFERENCES bill(id),
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_advbitem_bill ON advbitem(bill_id);
CREATE INDEX IF NOT EXISTS idx_advbitem_advance ON advbitem(advance_bill_id);

-- ============================================================
-- Article Code (ARGCODE)
-- Коды статей
-- ============================================================
CREATE TABLE IF NOT EXISTS argcode (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES argcode(id),
    code VARCHAR(16),
    kind SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    acc_id BIGINT REFERENCES account(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_argcode_parent ON argcode(parent_id);
CREATE INDEX IF NOT EXISTS idx_argcode_code ON argcode(code);

-- ============================================================
-- Balance (balance)
-- Остатки по счетам
-- ============================================================
CREATE TABLE IF NOT EXISTS balance (
    id BIGSERIAL PRIMARY KEY,
    acc_id BIGINT NOT NULL REFERENCES account(id),
    dt DATE NOT NULL,
    debit NUMERIC(18,4) NOT NULL DEFAULT 0,
    credit NUMERIC(18,4) NOT NULL DEFAULT 0,
    cur_id BIGINT DEFAULT 1,
    c_rate NUMERIC(18,9) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(acc_id, dt, cur_id)
);

CREATE INDEX IF NOT EXISTS idx_balance_acc ON balance(acc_id);
CREATE INDEX IF NOT EXISTS idx_balance_dt ON balance(dt);

-- ============================================================
-- Business Score (bizscore)
-- Бизнес-показатели
-- ============================================================
CREATE TABLE IF NOT EXISTS bizscore (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    obj_type BIGINT,
    obj_id BIGINT,
    value NUMERIC(18,4) DEFAULT 0,
    target NUMERIC(18,4),
    period_start DATE,
    period_end DATE,
    flags INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bizscore_obj ON bizscore(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_bizscore_period ON bizscore(period_start, period_end);

-- ============================================================
-- Business Score Global (bizsglob)
-- Глобальные бизнес-показатели
-- ============================================================
CREATE TABLE IF NOT EXISTS bizsglob (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    value NUMERIC(18,4) DEFAULT 0,
    value_str VARCHAR(512),
    flags INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Budget Item (budgitem)
-- Бюджетные статьи
-- ============================================================
CREATE TABLE IF NOT EXISTS budgitem (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES budgitem(id),
    acc_id BIGINT REFERENCES account(id),
    budget_version_id BIGINT REFERENCES budget_version(id),
    period_no INTEGER NOT NULL,
    plan_amount NUMERIC(18,4) DEFAULT 0,
    fact_amount NUMERIC(18,4) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_budgitem_parent ON budgitem(parent_id);
CREATE INDEX IF NOT EXISTS idx_budgitem_version ON budgitem(budget_version_id);

-- ============================================================
-- Contract Credit Ext (ccext)
-- Кредитные договоры
-- ============================================================
CREATE TABLE IF NOT EXISTS ccext (
    id BIGSERIAL PRIMARY KEY,
    contract_no VARCHAR(32) NOT NULL,
    party_id BIGINT REFERENCES person(id),
    loan_type SMALLINT NOT NULL DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL,
    interest_rate NUMERIC(8,4) NOT NULL,
    term_months INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_payment NUMERIC(18,4),
    collateral TEXT,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ccext_party ON ccext(party_id);
CREATE INDEX IF NOT EXISTS idx_ccext_status ON ccext(status);

-- ============================================================
-- Cash Check (ccheck)
-- Кассовые чеки
-- ============================================================
CREATE TABLE IF NOT EXISTS ccheck (
    id BIGSERIAL PRIMARY KEY,
    check_no INTEGER NOT NULL,
    session_id BIGINT REFERENCES cash_session(id),
    bill_id BIGINT REFERENCES bill(id),
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0,
    tax NUMERIC(18,4) DEFAULT 0,
    payment_type SMALLINT DEFAULT 1,
    payment_amount NUMERIC(18,4) DEFAULT 0,
    change_amount NUMERIC(18,4) DEFAULT 0,
    card_num VARCHAR(20),
    auth_code VARCHAR(8),
    fiscal_no BIGINT,
    fiscal_sign VARCHAR(64),
    is_fiscal BOOLEAN DEFAULT FALSE,
    is_void BOOLEAN DEFAULT FALSE,
    void_reason TEXT,
    cashier_id BIGINT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ccheck_session ON ccheck(session_id);
CREATE INDEX IF NOT EXISTS idx_ccheck_check_no ON ccheck(check_no);
CREATE INDEX IF NOT EXISTS idx_ccheck_dt ON ccheck(dt);

-- ============================================================
-- Credit Card Line (ccline)
-- Строки кредитных карт
-- ============================================================
CREATE TABLE IF NOT EXISTS ccline (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    ccext_id BIGINT REFERENCES ccext(id),
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    payment_no INTEGER,
    payment_dt DATE,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ccline_bill ON ccline(bill_id);
CREATE INDEX IF NOT EXISTS idx_ccline_ccext ON ccline(ccext_id);

-- ============================================================
-- Credit Card Line Ext (cclnext)
-- Расширение строк кредитных карт
-- ============================================================
CREATE TABLE IF NOT EXISTS cclnext (
    id BIGSERIAL PRIMARY KEY,
    ccline_id BIGINT NOT NULL REFERENCES ccline(id),
    trans_id BIGINT,
    rrn VARCHAR(12),
    auth_code VARCHAR(8),
    terminal_id VARCHAR(16),
    response_code VARCHAR(4),
    settle_date DATE,
    settle_status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Credit Card Payment (CCPAYM)
-- Платежи по кредитным картам
-- ============================================================
CREATE TABLE IF NOT EXISTS ccpaym (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    ccext_id BIGINT REFERENCES ccext(id),
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    payment_dt DATE NOT NULL,
    trans_id BIGINT,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ccpaym_bill ON ccpaym(bill_id);
CREATE INDEX IF NOT EXISTS idx_ccpaym_dt ON ccpaym(payment_dt);

-- ============================================================
-- Credit Current Price (ccurpric)
-- Кредитные цены
-- ============================================================
CREATE TABLE IF NOT EXISTS ccurpric (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    party_id BIGINT REFERENCES person(id),
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    credit_limit NUMERIC(18,4),
    payment_days INTEGER,
    valid_from DATE,
    valid_to DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, party_id, valid_from)
);

CREATE INDEX IF NOT EXISTS idx_ccurpric_goods ON ccurpric(goods_id);
CREATE INDEX IF NOT EXISTS idx_ccurpric_party ON ccurpric(party_id);

-- ============================================================
-- Cost Generation Line (cgline)
-- Строки калькуляции
-- ============================================================
CREATE TABLE IF NOT EXISTS cgline (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    goods_id BIGINT REFERENCES goods(id),
    material_cost NUMERIC(18,4) DEFAULT 0,
    labor_cost NUMERIC(18,4) DEFAULT 0,
    overhead_cost NUMERIC(18,4) DEFAULT 0,
    total_cost NUMERIC(18,4) DEFAULT 0,
    markup_percent NUMERIC(8,4) DEFAULT 0,
    sale_price NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cgline_bill ON cgline(bill_id);
CREATE INDEX IF NOT EXISTS idx_cgline_goods ON cgline(goods_id);

-- ============================================================
-- Check Operation (CHKOPJ)
-- Операции кассовых чеков
-- ============================================================
CREATE TABLE IF NOT EXISTS chkopj (
    id BIGSERIAL PRIMARY KEY,
    ccheck_id BIGINT REFERENCES ccheck(id),
    op_type SMALLINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chkopj_check ON chkopj(ccheck_id);

-- ============================================================
-- Counter Transfer (CPTRFR)
-- Внутрифирменные перемещения
-- ============================================================
CREATE TABLE IF NOT EXISTS cptrfr (
    id BIGSERIAL PRIMARY KEY,
    src_bill_id BIGINT REFERENCES bill(id),
    dst_bill_id BIGINT REFERENCES bill(id),
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cptrfr_src ON cptrfr(src_bill_id);
CREATE INDEX IF NOT EXISTS idx_cptrfr_dst ON cptrfr(dst_bill_id);

-- ============================================================
-- Crate (crate)
-- Тара
-- ============================================================
CREATE TABLE IF NOT EXISTS crate (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    goods_id BIGINT REFERENCES goods(id),
    qtty NUMERIC(18,4) DEFAULT 0,
    unit_id BIGINT REFERENCES unit(id),
    flags INTEGER DEFAULT 0,
    price NUMERIC(18,4),
    deposit_amount NUMERIC(18,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_crate_goods ON crate(goods_id);

-- ============================================================
-- Cash Session Ext (CSESS)
-- Расширение кассовой смены
-- ============================================================
CREATE TABLE IF NOT EXISTS csess (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES cash_session(id),
    opening_balance NUMERIC(18,4) DEFAULT 0,
    closing_balance NUMERIC(18,4),
    expected_balance NUMERIC(18,4),
    variance NUMERIC(18,4),
    z_report_no INTEGER,
    z_report_dt TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Currency Rates Ext (currest)
-- Расширенные курсы валют
-- ============================================================
CREATE TABLE IF NOT EXISTS currest (
    id BIGSERIAL PRIMARY KEY,
    cur_id BIGINT NOT NULL REFERENCES currency(id),
    rate_type_id BIGINT NOT NULL,
    rel_cur_id BIGINT NOT NULL REFERENCES currency(id),
    dt DATE NOT NULL,
    rate NUMERIC(18,9) NOT NULL,
    bid_rate NUMERIC(18,9),
    ask_rate NUMERIC(18,9),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cur_id, rate_type_id, rel_cur_id, dt)
);

CREATE INDEX IF NOT EXISTS idx_currest_cur ON currest(cur_id, dt);

-- ============================================================
-- Duty/License Sales (dls)
-- Продажи по лицензиям/пошлинам
-- ============================================================
CREATE TABLE IF NOT EXISTS dls (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    goods_id BIGINT REFERENCES goods(id),
    duty_amount NUMERIC(18,4) DEFAULT 0,
    license_fee NUMERIC(18,4) DEFAULT 0,
    country VARCHAR(64),
    hs_code VARCHAR(16),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dls_bill ON dls(bill_id);
CREATE INDEX IF NOT EXISTS idx_dls_goods ON dls(goods_id);

-- ============================================================
-- Duty/License Sales Offset (dlso)
-- Зачет пошлин/лицензий
-- ============================================================
CREATE TABLE IF NOT EXISTS dlso (
    id BIGSERIAL PRIMARY KEY,
    dls_id BIGINT NOT NULL REFERENCES dls(id),
    bill_id BIGINT REFERENCES bill(id),
    offset_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dlso_dls ON dlso(dls_id);
CREATE INDEX IF NOT EXISTS idx_dlso_bill ON dlso(bill_id);

-- ============================================================
-- Document Status (dstat)
-- Статусы документов
-- ============================================================
CREATE TABLE IF NOT EXISTS dstat (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    status_code SMALLINT NOT NULL,
    color INTEGER,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(status_code)
);

-- ============================================================
-- Email Address (EADDR)
-- Электронные адреса
-- ============================================================
CREATE TABLE IF NOT EXISTS eaddr (
    id BIGSERIAL PRIMARY KEY,
    party_id BIGINT NOT NULL REFERENCES person(id),
    address VARCHAR(256) NOT NULL,
    address_type SMALLINT DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_eaddr_party ON eaddr(party_id);

-- ============================================================
-- EGAIS Product (EGAISPROD)
-- Продукция ЕГАИС
-- ============================================================
CREATE TABLE IF NOT EXISTS egaisprod (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    egais_code VARCHAR(64) NOT NULL UNIQUE,
    alc_code VARCHAR(64),
    volume NUMERIC(8,2),
    strength NUMERIC(6,2),
    producer_inn VARCHAR(12),
    producer_kpp VARCHAR(9),
    producer_name VARCHAR(256),
    import_date DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_egaisprod_code ON egaisprod(egais_code);
CREATE INDEX IF NOT EXISTS idx_egaisprod_goods ON egaisprod(goods_id);

-- ============================================================
-- Goods Debt (GDSDEBT)
-- Задолженность по товарам
-- ============================================================
CREATE TABLE IF NOT EXISTS gdsdebt (
    id BIGSERIAL PRIMARY KEY,
    party_id BIGINT NOT NULL REFERENCES person(id),
    goods_id BIGINT REFERENCES goods(id),
    debt_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    due_date DATE,
    bill_id BIGINT REFERENCES bill(id),
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_gdsdebt_party ON gdsdebt(party_id);
CREATE INDEX IF NOT EXISTS idx_gdsdebt_goods ON gdsdebt(goods_id);
CREATE INDEX IF NOT EXISTS idx_gdsdebt_dt ON gdsdebt(dt);

-- ============================================================
-- Goods2 (goods2)
-- Расширенные товары (alternate/goods2)
-- ============================================================
CREATE TABLE IF NOT EXISTS goods2 (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    name VARCHAR(256),
    code VARCHAR(16),
    barcode VARCHAR(64),
    alt_code VARCHAR(16),
    supplier_id BIGINT REFERENCES person(id),
    supplier_code VARCHAR(32),
    min_price NUMERIC(18,4),
    max_price NUMERIC(18,4),
    last_purchase_price NUMERIC(18,4),
    last_sale_price NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, supplier_id)
);

CREATE INDEX IF NOT EXISTS idx_goods2_goods ON goods2(goods_id);
CREATE INDEX IF NOT EXISTS idx_goods2_supplier ON goods2(supplier_id);

-- ============================================================
-- Goods Extension (goodsext)
-- Расширенные атрибуты товаров
-- ============================================================
CREATE TABLE IF NOT EXISTS goodsext (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    weight NUMERIC(10,4),
    volume NUMERIC(10,4),
    dimensions VARCHAR(64),
    shelf_life_days INTEGER,
    min_temp NUMERIC(6,2),
    max_temp NUMERIC(6,2),
    storage_conditions TEXT,
    handling_notes TEXT,
    cert_no VARCHAR(32),
    cert_date DATE,
    cert_expiry DATE,
    country_of_origin VARCHAR(64),
    customs_decl_no VARCHAR(32),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id)
);

CREATE INDEX IF NOT EXISTS idx_goodsext_goods ON goodsext(goods_id);

-- ============================================================
-- Goods Status (gstat)
-- Статусы товаров
-- ============================================================
CREATE TABLE IF NOT EXISTS gstat (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    status_code SMALLINT NOT NULL UNIQUE,
    color INTEGER,
    flags INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Goods Tax Adj (gtaj)
-- Корректировка налогов по товарам
-- ============================================================
CREATE TABLE IF NOT EXISTS gtaj (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    tax_type SMALLINT NOT NULL,
    original_amount NUMERIC(18,4),
    adjusted_amount NUMERIC(18,4),
    adjustment_amount NUMERIC(18,4),
    bill_id BIGINT REFERENCES bill(id),
    dt DATE NOT NULL,
    reason TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_gtaj_goods ON gtaj(goods_id);
CREATE INDEX IF NOT EXISTS idx_gtaj_bill ON gtaj(bill_id);

-- ============================================================
-- Inventory (inventry)
-- Инвентаризация
-- ============================================================
CREATE TABLE IF NOT EXISTS inventry (
    id BIGSERIAL PRIMARY KEY,
    loc_id BIGINT NOT NULL REFERENCES location(id),
    op_id BIGINT REFERENCES op_kind(id),
    inv_no VARCHAR(16),
    dt DATE NOT NULL,
    status SMALLINT DEFAULT 0,
    memo TEXT,
    total_diff NUMERIC(18,4) DEFAULT 0,
    total_amount NUMERIC(18,4),
    approved_by BIGINT,
    approved_dt TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_inventry_loc ON inventry(loc_id);
CREATE INDEX IF NOT EXISTS idx_inventry_dt ON inventry(dt);
CREATE INDEX IF NOT EXISTS idx_inventry_status ON inventry(status);

-- ============================================================
-- Location Rest (lcrest)
-- Ограничения склада
-- ============================================================
CREATE TABLE IF NOT EXISTS lcrest (
    id BIGSERIAL PRIMARY KEY,
    loc_id BIGINT NOT NULL REFERENCES location(id),
    goods_id BIGINT REFERENCES goods(id),
    goods_group_id BIGINT,
    max_qtty NUMERIC(18,4),
    min_qtty NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(loc_id, goods_id)
);

CREATE INDEX IF NOT EXISTS idx_lcrest_loc ON lcrest(loc_id);
CREATE INDEX IF NOT EXISTS idx_lcrest_goods ON lcrest(goods_id);

-- ============================================================
-- Location Transfer (loctrfr)
-- Перемещения между складами
-- ============================================================
CREATE TABLE IF NOT EXISTS loctrfr (
    id BIGSERIAL PRIMARY KEY,
    src_loc_id BIGINT NOT NULL REFERENCES location(id),
    dst_loc_id BIGINT NOT NULL REFERENCES location(id),
    goods_id BIGINT REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4),
    bill_id BIGINT REFERENCES bill(id),
    status SMALLINT DEFAULT 0,
    dt DATE NOT NULL,
    shipped_dt DATE,
    received_dt DATE,
    waybill_no VARCHAR(32),
    memo TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_loctrfr_src ON loctrfr(src_loc_id);
CREATE INDEX IF NOT EXISTS idx_loctrfr_dst ON loctrfr(dst_loc_id);
CREATE INDEX IF NOT EXISTS idx_loctrfr_goods ON loctrfr(goods_id);
CREATE INDEX IF NOT EXISTS idx_loctrfr_dt ON loctrfr(dt);

-- ============================================================
-- Lot XCode (LOTXCODE)
-- Коды маркировки партий
-- ============================================================
CREATE TABLE IF NOT EXISTS lotxcode (
    id BIGSERIAL PRIMARY KEY,
    lot_id BIGINT NOT NULL REFERENCES lot(id),
    code VARCHAR(68) NOT NULL UNIQUE,
    code_type SMALLINT DEFAULT 0,
    status SMALLINT DEFAULT 0,
    scan_dt TIMESTAMP,
    used_dt TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lotxcode_lot ON lotxcode(lot_id);
CREATE INDEX IF NOT EXISTS idx_lotxcode_status ON lotxcode(status);

-- ============================================================
-- MRP Line (mrpline)
-- Строки MRP
-- ============================================================
CREATE TABLE IF NOT EXISTS mrpline (
    id BIGSERIAL PRIMARY KEY,
    mrp_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    demand_qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    supply_qtty NUMERIC(18,4) DEFAULT 0,
    plan_order_id BIGINT,
    priority SMALLINT DEFAULT 0,
    due_date DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mrpline_mrp ON mrpline(mrp_id);
CREATE INDEX IF NOT EXISTS idx_mrpline_goods ON mrpline(goods_id);

-- ============================================================
-- MRP Table (mrptab)
-- MRP таблицы
-- ============================================================
CREATE TABLE IF NOT EXISTS mrptab (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    goods_id BIGINT REFERENCES goods(id),
    loc_id BIGINT REFERENCES location(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mrptab_goods ON mrptab(goods_id);
CREATE INDEX IF NOT EXISTS idx_mrptab_loc ON mrptab(loc_id);

-- ============================================================
-- Object Association (objassoc)
-- Ассоциации объектов
-- ============================================================
CREATE TABLE IF NOT EXISTS objassoc (
    id BIGSERIAL PRIMARY KEY,
    assoc_type BIGINT NOT NULL,
    prmr_obj_type BIGINT NOT NULL,
    prmr_obj_id BIGINT NOT NULL,
    scnd_obj_type BIGINT NOT NULL,
    scnd_obj_id BIGINT NOT NULL,
    inner_num INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(assoc_type, prmr_obj_type, prmr_obj_id, scnd_obj_type, scnd_obj_id)
);

CREATE INDEX IF NOT EXISTS idx_objassoc_type ON objassoc(assoc_type);
CREATE INDEX IF NOT EXISTS idx_objassoc_prmr ON objassoc(prmr_obj_type, prmr_obj_id);
CREATE INDEX IF NOT EXISTS idx_objassoc_scnd ON objassoc(scnd_obj_type, scnd_obj_id);

-- ============================================================
-- Object Link (objliken)
-- Ссылки объектов
-- ============================================================
CREATE TABLE IF NOT EXISTS objliken (
    id BIGSERIAL PRIMARY KEY,
    obj_type1 BIGINT NOT NULL,
    obj_id1 BIGINT NOT NULL,
    obj_type2 BIGINT NOT NULL,
    obj_id2 BIGINT NOT NULL,
    link_type BIGINT NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type1, obj_id1, obj_type2, obj_id2)
);

CREATE INDEX IF NOT EXISTS idx_objliken_obj1 ON objliken(obj_type1, obj_id1);
CREATE INDEX IF NOT EXISTS idx_objliken_obj2 ON objliken(obj_type2, obj_id2);

-- ============================================================
-- Object Sync (objsync)
-- Синхронизация объектов
-- ============================================================
CREATE TABLE IF NOT EXISTS objsync (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    sync_id VARCHAR(64),
    remote_id VARCHAR(64),
    status SMALLINT DEFAULT 0,
    last_sync_dt TIMESTAMP,
    next_sync_dt TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type, obj_id)
);

CREATE INDEX IF NOT EXISTS idx_objsync_type ON objsync(obj_type);
CREATE INDEX IF NOT EXISTS idx_objsync_sync_id ON objsync(sync_id);

-- ============================================================
-- Object Sync Bulk (objsyncb)
-- Групповая синхронизация
-- ============================================================
CREATE TABLE IF NOT EXISTS objsyncb (
    id BIGSERIAL PRIMARY KEY,
    batch_id VARCHAR(64) NOT NULL,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    operation SMALLINT NOT NULL,
    status SMALLINT DEFAULT 0,
    error_msg TEXT,
    processed_dt TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(batch_id, obj_type, obj_id)
);

CREATE INDEX IF NOT EXISTS idx_objsyncb_batch ON objsyncb(batch_id);
CREATE INDEX IF NOT EXISTS idx_objsyncb_status ON objsyncb(status);

-- ============================================================
-- Object Sync Queue (objsyque)
-- Очередь синхронизации
-- ============================================================
CREATE TABLE IF NOT EXISTS objsyque (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    operation SMALLINT NOT NULL,
    priority SMALLINT DEFAULT 0,
    status SMALLINT DEFAULT 0,
    retry_count INTEGER DEFAULT 0,
    next_retry_dt TIMESTAMP,
    error_msg TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_dt TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_objsyque_status ON objsyque(status);
CREATE INDEX IF NOT EXISTS idx_objsyque_priority ON objsyque(priority, created_at);

-- ============================================================
-- Object Tag (objtag)
-- Теги объектов
-- ============================================================
CREATE TABLE IF NOT EXISTS objtag (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    tag VARCHAR(64) NOT NULL,
    value TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type, obj_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_objtag_obj ON objtag(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_objtag_tag ON objtag(tag);

-- ============================================================
-- Object Version (OBJVER)
-- Версии объектов
-- ============================================================
CREATE TABLE IF NOT EXISTS objver (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    version INTEGER NOT NULL,
    data JSONB,
    created_by BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type, obj_id, version)
);

CREATE INDEX IF NOT EXISTS idx_objver_obj ON objver(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_objver_version ON objver(obj_type, obj_id, version);

-- ============================================================
-- Package (package)
-- Упаковка
-- ============================================================
CREATE TABLE IF NOT EXISTS package (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    goods_id BIGINT REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    weight NUMERIC(10,4),
    dimensions VARCHAR(64),
    barcode VARCHAR(64),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_package_goods ON package(goods_id);

-- ============================================================
-- Payment Plan (payplan)
-- План платежей
-- ============================================================
CREATE TABLE IF NOT EXISTS payplan (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    pay_no INTEGER NOT NULL,
    pay_date DATE NOT NULL,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    is_paid BOOLEAN DEFAULT FALSE,
    paid_dt DATE,
    paid_amount NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(bill_id, pay_no)
);

CREATE INDEX IF NOT EXISTS idx_payplan_bill ON payplan(bill_id);
CREATE INDEX IF NOT EXISTS idx_payplan_date ON payplan(pay_date);

-- ============================================================
-- Package Link (pckglink)
-- Связи упаковок
-- ============================================================
CREATE TABLE IF NOT EXISTS pckglink (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    package_id BIGINT NOT NULL REFERENCES package(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    is_default BOOLEAN DEFAULT FALSE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, package_id)
);

CREATE INDEX IF NOT EXISTS idx_pckglink_goods ON pckglink(goods_id);

-- ============================================================
-- Person Kind (perskind)
-- Виды контрагентов
-- ============================================================
CREATE TABLE IF NOT EXISTS perskind (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    parent_id BIGINT REFERENCES perskind(id),
    flags INTEGER DEFAULT 0,
    discount_percent NUMERIC(6,2),
    credit_limit NUMERIC(18,4),
    payment_days INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_perskind_parent ON perskind(parent_id);

-- ============================================================
-- Price Line (pline)
-- Строки прайса
-- ============================================================
CREATE TABLE IF NOT EXISTS pline (
    id BIGSERIAL PRIMARY KEY,
    price_list_id BIGINT NOT NULL REFERENCES price_list(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    min_qtty NUMERIC(18,4) DEFAULT 1,
    discount_percent NUMERIC(6,2) DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(price_list_id, goods_id, valid_from)
);

CREATE INDEX IF NOT EXISTS idx_pline_list ON pline(price_list_id);
CREATE INDEX IF NOT EXISTS idx_pline_goods ON pline(goods_id);

-- ============================================================
-- Price List (plist)
-- Прайс-листы
-- ============================================================
CREATE TABLE IF NOT EXISTS plist (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    valid_from DATE,
    valid_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    is_auto_update BOOLEAN DEFAULT FALSE,
    update_frequency SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_plist_valid ON plist(valid_from, valid_to);

-- ============================================================
-- POS Load (posload)
-- Загрузка POS
-- ============================================================
CREATE TABLE IF NOT EXISTS posload (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT REFERENCES device(id),
    goods_id BIGINT REFERENCES goods(id),
    plu INTEGER,
    price NUMERIC(18,4),
    is_active BOOLEAN DEFAULT TRUE,
    last_update TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(device_id, goods_id)
);

CREATE INDEX IF NOT EXISTS idx_posload_device ON posload(device_id);
CREATE INDEX IF NOT EXISTS idx_posload_plu ON posload(plu);

-- ============================================================
-- Project Task (prjtask)
-- Задачи проекта
-- ============================================================
CREATE TABLE IF NOT EXISTS prjtask (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL,
    parent_id BIGINT REFERENCES prjtask(id),
    name VARCHAR(256) NOT NULL,
    description TEXT,
    status SMALLINT DEFAULT 0,
    priority SMALLINT DEFAULT 1,
    start_date DATE,
    due_date DATE,
    complete_date DATE,
    progress_percent SMALLINT DEFAULT 0,
    assigned_to BIGINT,
    estimated_hours NUMERIC(8,2),
    actual_hours NUMERIC(8,2),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_prjtask_project ON prjtask(project_id);
CREATE INDEX IF NOT EXISTS idx_prjtask_parent ON prjtask(parent_id);
CREATE INDEX IF NOT EXISTS idx_prjtask_status ON prjtask(status);

-- ============================================================
-- Processor (processr)
-- Процессоры/обработчики
-- ============================================================
CREATE TABLE IF NOT EXISTS processr (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    proc_type SMALLINT NOT NULL,
    config JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    last_run_dt TIMESTAMP,
    next_run_dt TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_processr_type ON processr(proc_type);
CREATE INDEX IF NOT EXISTS idx_processr_active ON processr(is_active);

-- ============================================================
-- Project (project)
-- Проекты
-- ============================================================
CREATE TABLE IF NOT EXISTS project (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    description TEXT,
    owner_id BIGINT,
    status SMALLINT DEFAULT 0,
    start_date DATE,
    end_date DATE,
    budget NUMERIC(18,4),
    progress_percent SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_project_status ON project(status);
CREATE INDEX IF NOT EXISTS idx_project_owner ON project(owner_id);

-- ============================================================
-- Properties (prop)
-- Свойства
-- ============================================================
CREATE TABLE IF NOT EXISTS prop (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    prop_type SMALLINT NOT NULL DEFAULT 0,
    parent_id BIGINT REFERENCES prop(id),
    kind_id BIGINT,
    code VARCHAR(16),
    is_list BOOLEAN DEFAULT FALSE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_prop_parent ON prop(parent_id);
CREATE INDEX IF NOT EXISTS idx_prop_kind ON prop(kind_id);

-- ============================================================
-- Person Sales (psales)
-- Продажи персон
-- ============================================================
CREATE TABLE IF NOT EXISTS psales (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    dt DATE NOT NULL,
    total_amount NUMERIC(18,4) DEFAULT 0,
    discount_amount NUMERIC(18,4) DEFAULT 0,
    return_amount NUMERIC(18,4) DEFAULT 0,
    bill_count INTEGER DEFAULT 0,
    avg_bill_amount NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(person_id, dt)
);

CREATE INDEX IF NOT EXISTS idx_psales_person ON psales(person_id);
CREATE INDEX IF NOT EXISTS idx_psales_dt ON psales(dt);

-- ============================================================
-- Person Sync Event (psnevent)
-- События синхронизации персон
-- ============================================================
CREATE TABLE IF NOT EXISTS psnevent (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    event_type SMALLINT NOT NULL,
    event_data JSONB,
    processed BOOLEAN DEFAULT FALSE,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_dt TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_psnevent_person ON psnevent(person_id);
CREATE INDEX IF NOT EXISTS idx_psnevent_processed ON psnevent(processed);

-- ============================================================
-- Person Sync Post (psnpost)
-- Пост-обработка синхронизации
-- ============================================================
CREATE TABLE IF NOT EXISTS psnpost (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    sync_id BIGINT NOT NULL,
    operation SMALLINT NOT NULL,
    status SMALLINT DEFAULT 0,
    error_msg TEXT,
    retry_count INTEGER DEFAULT 0,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_dt TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_psnpost_person ON psnpost(person_id);
CREATE INDEX IF NOT EXISTS idx_psnpost_sync ON psnpost(sync_id);

-- ============================================================
-- Quality Certificate (qcert)
-- Сертификаты качества
-- ============================================================
CREATE TABLE IF NOT EXISTS qcert (
    id BIGSERIAL PRIMARY KEY,
    cert_no VARCHAR(32) NOT NULL UNIQUE,
    goods_id BIGINT REFERENCES goods(id),
    cert_type SMALLINT NOT NULL,
    issuer VARCHAR(256),
    issue_date DATE NOT NULL,
    expiry_date DATE,
    status SMALLINT DEFAULT 0,
    doc_file BYTEA,
    notes TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_qcert_goods ON qcert(goods_id);
CREATE INDEX IF NOT EXISTS idx_qcert_expiry ON qcert(expiry_date);

-- ============================================================
-- Quote (quot)
-- Коммерческие предложения
-- ============================================================
CREATE TABLE IF NOT EXISTS quot (
    id BIGSERIAL PRIMARY KEY,
    quot_no VARCHAR(16) NOT NULL,
    party_id BIGINT REFERENCES person(id),
    contact_id BIGINT,
    dt DATE NOT NULL,
    valid_to DATE,
    amount NUMERIC(18,4) DEFAULT 0,
    currency_id BIGINT DEFAULT 1,
    status SMALLINT DEFAULT 0,
    notes TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_quot_party ON quot(party_id);
CREATE INDEX IF NOT EXISTS idx_quot_dt ON quot(dt);
CREATE INDEX IF NOT EXISTS idx_quot_status ON quot(status);

-- ============================================================
-- Quote2 (quot2)
-- Расширенные коммерческие предложения
-- ============================================================
CREATE TABLE IF NOT EXISTS quot2 (
    id BIGSERIAL PRIMARY KEY,
    quot_id BIGINT NOT NULL REFERENCES quot(id),
    payment_terms VARCHAR(256),
    delivery_terms VARCHAR(256),
    warranty_months INTEGER,
    discount_percent NUMERIC(6,2),
    discount_amount NUMERIC(18,4),
    tax_amount NUMERIC(18,4),
    total_amount NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Quote Relation (quotrel)
-- Связи коммерческих предложений
-- ============================================================
CREATE TABLE IF NOT EXISTS quotrel (
    id BIGSERIAL PRIMARY KEY,
    quot_id BIGINT NOT NULL REFERENCES quot(id),
    related_quot_id BIGINT REFERENCES quot(id),
    bill_id BIGINT REFERENCES bill(id),
    rel_type SMALLINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(quot_id, related_quot_id)
);

CREATE INDEX IF NOT EXISTS idx_quotrel_quot ON quotrel(quot_id);

-- ============================================================
-- Reference2 (ref2)
-- Дополнительные ссылки
-- ============================================================
CREATE TABLE IF NOT EXISTS ref2 (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    ref_type BIGINT NOT NULL,
    ref_value VARCHAR(512),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type, obj_id, ref_type)
);

CREATE INDEX IF NOT EXISTS idx_ref2_obj ON ref2(obj_type, obj_id);

-- ============================================================
-- Register (REGISTER)
-- Регистрации (ИНН, КПП и др.)
-- ============================================================
CREATE TABLE IF NOT EXISTS register (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    reg_type_id BIGINT NOT NULL,
    number VARCHAR(128) NOT NULL,
    series VARCHAR(32),
    issued_by VARCHAR(256),
    issue_date DATE,
    expiry_date DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_register_person ON register(person_id);
CREATE INDEX IF NOT EXISTS idx_register_type ON register(reg_type_id);
CREATE INDEX IF NOT EXISTS idx_register_number ON register(number);

-- ============================================================
-- Salary (salary)
-- Зарплата
-- ============================================================
CREATE TABLE IF NOT EXISTS salary (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    dt DATE NOT NULL,
    gross_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(18,4) DEFAULT 0,
    insurance_amount NUMERIC(18,4) DEFAULT 0,
    net_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    salary_type SMALLINT DEFAULT 0,
    hours NUMERIC(6,2),
    rate NUMERIC(8,4),
    bonus_amount NUMERIC(18,4) DEFAULT 0,
    deduction_amount NUMERIC(18,4) DEFAULT 0,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, dt, salary_type)
);

CREATE INDEX IF NOT EXISTS idx_salary_employee ON salary(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_dt ON salary(dt);
CREATE INDEX IF NOT EXISTS idx_salary_status ON salary(status);

-- ============================================================
-- Sale (sale)
-- Продажи
-- ============================================================
CREATE TABLE IF NOT EXISTS sale (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    party_id BIGINT REFERENCES person(id),
    goods_id BIGINT REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    profit NUMERIC(18,4),
    dt DATE NOT NULL,
    loc_id BIGINT REFERENCES location(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sale_bill ON sale(bill_id);
CREATE INDEX IF NOT EXISTS idx_sale_party ON sale(party_id);
CREATE INDEX IF NOT EXISTS idx_sale_goods ON sale(goods_id);
CREATE INDEX IF NOT EXISTS idx_sale_dt ON sale(dt);

-- ============================================================
-- Service Card (SCARD)
-- Дисконтные карты
-- ============================================================
CREATE TABLE IF NOT EXISTS scard (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    card_type SMALLINT NOT NULL DEFAULT 0,
    party_id BIGINT REFERENCES person(id),
    discount_percent NUMERIC(6,2) DEFAULT 0,
    bonus_amount NUMERIC(18,4) DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    issue_dt DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scard_party ON scard(party_id);
CREATE INDEX IF NOT EXISTS idx_scard_type ON scard(card_type);

-- ============================================================
-- Service Card Operations (SCARDOP)
-- Операции дисконтных карт
-- ============================================================
CREATE TABLE IF NOT EXISTS scardop (
    id BIGSERIAL PRIMARY KEY,
    scard_id BIGINT NOT NULL REFERENCES scard(id),
    bill_id BIGINT REFERENCES bill(id),
    op_type SMALLINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    bonus_delta NUMERIC(18,4) DEFAULT 0,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scardop_card ON scardop(scard_id);
CREATE INDEX IF NOT EXISTS idx_scardop_bill ON scardop(bill_id);
CREATE INDEX IF NOT EXISTS idx_scardop_dt ON scardop(dt);

-- ============================================================
-- Salary Journal (SJ)
-- Журнал зарплаты
-- ============================================================
CREATE TABLE IF NOT EXISTS sj (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    dt DATE NOT NULL,
    op_type SMALLINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    acc_id BIGINT REFERENCES account(id),
    bill_id BIGINT REFERENCES bill(id),
    memo TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sj_employee ON sj(employee_id);
CREATE INDEX IF NOT EXISTS idx_sj_dt ON sj(dt);

-- ============================================================
-- Salary Journal Register (SJR)
-- Регистр журнала зарплаты
-- ============================================================
CREATE TABLE IF NOT EXISTS sjr (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    gross_total NUMERIC(18,4) DEFAULT 0,
    tax_total NUMERIC(18,4) DEFAULT 0,
    insurance_total NUMERIC(18,4) DEFAULT 0,
    net_total NUMERIC(18,4) DEFAULT 0,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS idx_sjr_employee ON sjr(employee_id);
CREATE INDEX IF NOT EXISTS idx_sjr_period ON sjr(period_start, period_end);

-- ============================================================
-- Specifications (spcsn)
-- Спецификации
-- ============================================================
CREATE TABLE IF NOT EXISTS spcsn (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    component_goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    yield_percent NUMERIC(6,2),
    is_optional BOOLEAN DEFAULT FALSE,
    seq_no INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, component_goods_id)
);

CREATE INDEX IF NOT EXISTS idx_spcsn_goods ON spcsn(goods_id);
CREATE INDEX IF NOT EXISTS idx_spcsn_component ON spcsn(component_goods_id);

-- ============================================================
-- Staff Calendar (stafcal)
-- Календарь персонала
-- ============================================================
CREATE TABLE IF NOT EXISTS stafcal (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    dt DATE NOT NULL,
    hours NUMERIC(4,2),
    work_type SMALLINT DEFAULT 0,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, dt)
);

CREATE INDEX IF NOT EXISTS idx_stafcal_employee ON stafcal(employee_id);
CREATE INDEX IF NOT EXISTS idx_stafcal_dt ON stafcal(dt);

-- ============================================================
-- Staff List (staffl)
-- Список персонала
-- ============================================================
CREATE TABLE IF NOT EXISTS staffl (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    tab_no VARCHAR(16),
    department_id BIGINT REFERENCES department(id),
    position_id BIGINT REFERENCES position(id),
    hire_date DATE NOT NULL,
    fire_date DATE,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(person_id)
);

CREATE INDEX IF NOT EXISTS idx_staffl_tab ON staffl(tab_no);
CREATE INDEX IF NOT EXISTS idx_staffl_dept ON staffl(department_id);
CREATE INDEX IF NOT EXISTS idx_staffl_status ON staffl(status);

-- ============================================================
-- Tech (tech)
-- Технологии
-- ============================================================
CREATE TABLE IF NOT EXISTS tech (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    version INTEGER NOT NULL DEFAULT 1,
    name VARCHAR(256),
    output_qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    output_unit_id BIGINT REFERENCES unit(id),
    is_active BOOLEAN DEFAULT FALSE,
    is_current BOOLEAN DEFAULT FALSE,
    description TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    UNIQUE(goods_id, version)
);

CREATE INDEX IF NOT EXISTS idx_tech_goods ON tech(goods_id);
CREATE INDEX IF NOT EXISTS idx_tech_active ON tech(is_active);

-- ============================================================
-- Text Reference (TEXTREF)
-- Текстовые ссылки
-- ============================================================
CREATE TABLE IF NOT EXISTS textref (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    text TEXT,
    lang VARCHAR(8) DEFAULT 'ru',
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type, obj_id, lang)
);

CREATE INDEX IF NOT EXISTS idx_textref_obj ON textref(obj_type, obj_id);

-- ============================================================
-- Transfer (transfer)
-- Перемещения
-- ============================================================
CREATE TABLE IF NOT EXISTS transfer (
    id BIGSERIAL PRIMARY KEY,
    src_loc_id BIGINT NOT NULL REFERENCES location(id),
    dst_loc_id BIGINT NOT NULL REFERENCES location(id),
    goods_id BIGINT REFERENCES goods(id),
    qtty NUMERIC(18,4),
    price NUMERIC(18,4),
    status SMALLINT NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    shipped_dt DATE,
    received_dt DATE,
    waybill_no VARCHAR(32),
    memo TEXT,
    bill_id BIGINT REFERENCES bill(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_transfer_src ON transfer(src_loc_id);
CREATE INDEX IF NOT EXISTS idx_transfer_dst ON transfer(dst_loc_id);
CREATE INDEX IF NOT EXISTS idx_transfer_goods ON transfer(goods_id);
CREATE INDEX IF NOT EXISTS idx_transfer_dt ON transfer(dt);
CREATE INDEX IF NOT EXISTS idx_transfer_status ON transfer(status);

-- ============================================================
-- Terminal Session (tsess)
-- Сессия терминала
-- ============================================================
CREATE TABLE IF NOT EXISTS tsess (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES device(id),
    session_no INTEGER NOT NULL,
    cashier_id BIGINT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_dt TIMESTAMP,
    status SMALLINT DEFAULT 0,
    total_amount NUMERIC(18,4) DEFAULT 0,
    total_discount NUMERIC(18,4) DEFAULT 0,
    total_tax NUMERIC(18,4) DEFAULT 0,
    op_count INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tsess_device ON tsess(device_id);
CREATE INDEX IF NOT EXISTS idx_tsess_dt ON tsess(dt);
CREATE INDEX IF NOT EXISTS idx_tsess_status ON tsess(status);

-- ============================================================
-- Terminal Session Line (tsessln)
-- Строки сессии терминала
-- ============================================================
CREATE TABLE IF NOT EXISTS tsessln (
    id BIGSERIAL PRIMARY KEY,
    tsess_id BIGINT NOT NULL REFERENCES tsess(id),
    line_no SMALLINT NOT NULL,
    goods_id BIGINT REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(18,4) DEFAULT 0,
    payment_type SMALLINT DEFAULT 1,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tsessln_session ON tsessln(tsess_id);
CREATE INDEX IF NOT EXISTS idx_tsessln_goods ON tsessln(goods_id);

-- ============================================================
-- Unix Text Reference (UNXTXREF)
-- Unix-текстовые ссылки
-- ============================================================
CREATE TABLE IF NOT EXISTS unxtxref (
    id BIGSERIAL PRIMARY KEY,
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    ref_key VARCHAR(64) NOT NULL,
    ref_value TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(obj_type, obj_id, ref_key)
);

CREATE INDEX IF NOT EXISTS idx_unxtxref_obj ON unxtxref(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_unxtxref_key ON unxtxref(ref_key);

-- ============================================================
-- VAT Book (vatbook)
-- Книга продаж/покупок НДС
-- ============================================================
CREATE TABLE IF NOT EXISTS vatbook (
    id BIGSERIAL PRIMARY KEY,
    book_type SMALLINT NOT NULL,
    period DATE NOT NULL,
    bill_id BIGINT REFERENCES bill(id),
    seller_id BIGINT REFERENCES person(id),
    buyer_id BIGINT REFERENCES person(id),
    invoice_no VARCHAR(32),
    invoice_dt DATE,
    total_amount NUMERIC(18,4) DEFAULT 0,
    vat_amount NUMERIC(18,4) DEFAULT 0,
    vat_rate NUMERIC(6,2),
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(book_type, period, bill_id)
);

CREATE INDEX IF NOT EXISTS idx_vatbook_type ON vatbook(book_type);
CREATE INDEX IF NOT EXISTS idx_vatbook_period ON vatbook(period);
CREATE INDEX IF NOT EXISTS idx_vatbook_bill ON vatbook(bill_id);

-- ============================================================
-- Workbook (WORKBOOK)
-- Рабочая тетрадь
-- ============================================================
CREATE TABLE IF NOT EXISTS workbook (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    owner_id BIGINT NOT NULL,
    sheet_count INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workbook_owner ON workbook(owner_id);
CREATE INDEX IF NOT EXISTS idx_workbook_status ON workbook(status);

-- ============================================================
-- World (world)
-- Справочник стран/регионов
-- ============================================================
CREATE TABLE IF NOT EXISTS world (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    name_en VARCHAR(256),
    iso_code VARCHAR(2),
    iso_code3 VARCHAR(3),
    phone_code VARCHAR(8),
    parent_id BIGINT REFERENCES world(id),
    level SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_world_parent ON world(parent_id);
CREATE INDEX IF NOT EXISTS idx_world_iso ON world(iso_code);
CREATE INDEX IF NOT EXISTS idx_world_level ON world(level);

-- ============================================================
-- Article (article)
-- Статьи
-- ============================================================
CREATE TABLE IF NOT EXISTS article (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES article(id),
    code VARCHAR(16),
    kind SMALLINT NOT NULL DEFAULT 0,
    acc_id BIGINT REFERENCES account(id),
    flags INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_article_parent ON article(parent_id);
CREATE INDEX IF NOT EXISTS idx_article_code ON article(code);
CREATE INDEX IF NOT EXISTS idx_article_kind ON article(kind);

-- ============================================================
-- Bill Amount (billamt)
-- Суммы документа (расширенные)
-- ============================================================
CREATE TABLE IF NOT EXISTS billamt (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    amt_type_id SMALLINT NOT NULL,
    cur_id BIGINT NOT NULL DEFAULT 1,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    rate NUMERIC(18,9) DEFAULT 1,
    base_amount NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(bill_id, amt_type_id, cur_id)
);

CREATE INDEX IF NOT EXISTS idx_billamt_bill ON billamt(bill_id);
CREATE INDEX IF NOT EXISTS idx_billamt_type ON billamt(amt_type_id);

-- ============================================================
-- Bank Account (bnkacct)
-- Банковские счета
-- ============================================================
CREATE TABLE IF NOT EXISTS bnkacct (
    id BIGSERIAL PRIMARY KEY,
    party_id BIGINT REFERENCES person(id),
    bank_name VARCHAR(256) NOT NULL,
    account VARCHAR(32) NOT NULL,
    account_type SMALLINT DEFAULT 0,
    cor_account VARCHAR(32),
    bik VARCHAR(9),
    inn VARCHAR(12),
    kpp VARCHAR(9),
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(party_id, account)
);

CREATE INDEX IF NOT EXISTS idx_bnkacct_party ON bnkacct(party_id);
CREATE INDEX IF NOT EXISTS idx_bnkacct_bik ON bnkacct(bik);

-- ============================================================
-- Insert default data for new tables
-- ============================================================

-- Default document statuses
INSERT INTO dstat (name, status_code, color, flags) VALUES
    ('Черновик', 0, 16777215, 0),
    ('Подтверждён', 1, 65280, 0),
    ('Проведён', 2, 255, 0),
    ('Отменён', 3, 8421504, 0),
    ('Архивный', 4, 12632256, 0)
ON CONFLICT DO NOTHING;

-- Default goods statuses
INSERT INTO gstat (name, status_code, color, flags) VALUES
    ('Активен', 0, 65280, 0),
    ('Неактивен', 1, 12632256, 0),
    ('Снят с производства', 2, 16711680, 0),
    ('Ожидается', 3, 16776960, 0)
ON CONFLICT DO NOTHING;

-- Default payment types
INSERT INTO perskind (name, code, discount_percent, payment_days) VALUES
    ('Покупатель', 'BUYER', 0, 30),
    ('Поставщик', 'SUPPLIER', 0, 0),
    ('Покупатель и поставщик', 'BOTH', 0, 30),
    ('Сотрудник', 'EMP', 0, 0)
ON CONFLICT DO NOTHING;

-- Default card types
INSERT INTO scard (code, card_type, discount_percent, valid_from) VALUES
    ('DEFAULT', 0, 0, CURRENT_DATE)
ON CONFLICT DO NOTHING;
