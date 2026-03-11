-- ============================================================
-- Additional Tables - Tax, Security, EDI
-- Add to existing schema
-- ============================================================

-- ============================================================
-- Tax Tables - Налоги
-- ============================================================

-- Tax groups
CREATE TABLE IF NOT EXISTS tax_group (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    rate NUMERIC(6,2) NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- VAT rates
CREATE TABLE IF NOT EXISTS vat_rate (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    percent NUMERIC(6,2) NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tax invoices
CREATE TABLE IF NOT EXISTS tax_invoice (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    dt DATE NOT NULL,
    number VARCHAR(16) NOT NULL,
    seller_id BIGINT REFERENCES person(id),
    buyer_id BIGINT REFERENCES person(id),
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(number)
);

CREATE INDEX IF NOT EXISTS idx_tax_invoice_dt ON tax_invoice(dt);
CREATE INDEX IF NOT EXISTS idx_tax_invoice_seller ON tax_invoice(seller_id);
CREATE INDEX IF NOT EXISTS idx_tax_invoice_buyer ON tax_invoice(buyer_id);

-- Goods tax config
CREATE TABLE IF NOT EXISTS goods_tax_config (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    tax_grp_id BIGINT REFERENCES tax_group(id),
    vat_rate_id BIGINT REFERENCES vat_rate(id),
    excise NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    UNIQUE(goods_id)
);

-- Default VAT rates
INSERT INTO vat_rate (name, percent, flags) VALUES
    ('Без НДС', 0, 0),
    ('НДС 10%', 10, 0),
    ('НДС 20%', 20, 0)
ON CONFLICT DO NOTHING;

-- ============================================================
-- Security Tables - Безопасность
-- ============================================================

-- Users
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    login VARCHAR(64) NOT NULL UNIQUE,
    password VARCHAR(128) NOT NULL,
    email VARCHAR(128),
    phone VARCHAR(32),
    group_id BIGINT,
    main_org_id BIGINT,
    flags INTEGER DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_login ON users(login);
CREATE INDEX IF NOT EXISTS idx_users_group ON users(group_id);

-- Default administrator
INSERT INTO users (id, name, login, password, email, flags, status) VALUES
    (1, 'Администратор', 'admin', 'admin', 'admin@surypus.local', 1, 0)
ON CONFLICT (id) DO NOTHING;

-- User groups
CREATE TABLE IF NOT EXISTS user_group (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User rights
CREATE TABLE IF NOT EXISTS user_rights (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rights INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id)
);

-- Sessions
CREATE TABLE IF NOT EXISTS session (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_dt TIMESTAMP,
    ip VARCHAR(64),
    token VARCHAR(64) NOT NULL UNIQUE,
    status SMALLINT NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_session_token ON session(token);
CREATE INDEX IF NOT EXISTS idx_session_user ON session(user_id);

-- Object rights
CREATE TABLE IF NOT EXISTS object_rights (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    obj_type BIGINT NOT NULL,
    obj_id BIGINT NOT NULL,
    flags INTEGER NOT NULL DEFAULT 0,
    UNIQUE(user_id, obj_type, obj_id)
);

-- Audit log
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    action VARCHAR(32) NOT NULL,
    obj_type BIGINT,
    obj_id BIGINT,
    details TEXT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_obj ON audit_log(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_dt ON audit_log(dt);

-- Password history
CREATE TABLE IF NOT EXISTS password_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    password VARCHAR(128) NOT NULL,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_password_history_user ON password_history(user_id);

-- ============================================================
-- EDI Tables - EDI/ЕГАИС
-- ============================================================

-- EDI partners
CREATE TABLE IF NOT EXISTS edi_partner (
    id BIGSERIAL PRIMARY KEY,
    gln VARCHAR(20) NOT NULL UNIQUE,
    inn VARCHAR(12) NOT NULL,
    kpp VARCHAR(9),
    name VARCHAR(256) NOT NULL,
    partner_type SMALLINT NOT NULL DEFAULT 0,
    edi_id VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_edi_partner_inn ON edi_partner(inn);

-- EDI messages
CREATE TABLE IF NOT EXISTS edi_message (
    id BIGSERIAL PRIMARY KEY,
    msg_type SMALLINT NOT NULL,
    direction SMALLINT NOT NULL,
    partner_id BIGINT REFERENCES edi_partner(id),
    bill_id BIGINT REFERENCES bill(id),
    content TEXT,
    status SMALLINT NOT NULL DEFAULT 0,
    error TEXT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_edi_message_dt ON edi_message(dt);
CREATE INDEX IF NOT EXISTS idx_edi_message_status ON edi_message(status);

-- EGAIS operations
CREATE TABLE IF NOT EXISTS egais_operation (
    id BIGSERIAL PRIMARY KEY,
    op_type SMALLINT NOT NULL,
    bill_id BIGINT REFERENCES bill(id),
    xml TEXT,
    status SMALLINT NOT NULL DEFAULT 0,
    reply_id BIGINT,
    reply_xml TEXT,
    comment TEXT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_egais_op_bill ON egais_operation(bill_id);
CREATE INDEX IF NOT EXISTS idx_egais_op_dt ON egais_operation(dt);

-- EGAIS marks
CREATE TABLE IF NOT EXISTS egais_mark (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(68) NOT NULL UNIQUE,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    bill_id BIGINT REFERENCES bill(id),
    box_id BIGINT,
    status SMALLINT NOT NULL DEFAULT 0,
    scan_dt TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_egais_mark_goods ON egais_mark(goods_id);
CREATE INDEX IF NOT EXISTS idx_egais_mark_bill ON egais_mark(bill_id);
CREATE INDEX IF NOT EXISTS idx_egais_mark_status ON egais_mark(status);

-- EGAIS waybills
CREATE TABLE IF NOT EXISTS egais_waybill (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(20) NOT NULL,
    dt DATE NOT NULL,
    wb_type SMALLINT NOT NULL,
    sender_inn VARCHAR(12) NOT NULL,
    receiver_inn VARCHAR(12) NOT NULL,
    content TEXT,
    status SMALLINT NOT NULL DEFAULT 0,
    comment TEXT,
    bill_id BIGINT REFERENCES bill(id),
    fp VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    UNIQUE(number, dt)
);

CREATE INDEX IF NOT EXISTS idx_egais_waybill_sender ON egais_waybill(sender_inn);
CREATE INDEX IF NOT EXISTS idx_egais_waybill_receiver ON egais_waybill(receiver_inn);

-- EGAIS inventory
CREATE TABLE IF NOT EXISTS egais_inventory (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(20) NOT NULL,
    dt DATE NOT NULL,
    inv_type SMALLINT NOT NULL,
    content TEXT,
    status SMALLINT NOT NULL DEFAULT 0,
    result_content TEXT,
    reply_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    UNIQUE(number, dt)
);

-- EGAIS requests
CREATE TABLE IF NOT EXISTS egais_request (
    id BIGSERIAL PRIMARY KEY,
    req_type SMALLINT NOT NULL,
    content TEXT,
    status SMALLINT NOT NULL DEFAULT 0,
    result TEXT,
    reply_id BIGINT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- EGAIS balance
CREATE TABLE IF NOT EXISTS egais_balance (
    id BIGSERIAL PRIMARY KEY,
    org_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    quantity NUMERIC(18,4) NOT NULL DEFAULT 0,
    unit VARCHAR(16) DEFAULT '0',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(org_id, goods_id)
);

CREATE INDEX IF NOT EXISTS idx_egais_balance_org ON egais_balance(org_id);
