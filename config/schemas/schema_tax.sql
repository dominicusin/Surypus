-- ============================================================
-- Tax Tables - Налоги
-- Соответствует C++ gtax.cpp
-- ============================================================

-- Taxes (справочник налогов)
CREATE TABLE IF NOT EXISTS tax (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    ttype SMALLINT NOT NULL,  -- 0=VAT, 1=VATZERO, 2=EXCISE, 3=SALES, 4=PROPERTY, 5=INCOME
    rate NUMERIC(5,4) NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(name)
);

-- Tax groups (налоговые группы товаров)
CREATE TABLE IF NOT EXISTS tax_grp (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    tax_id BIGINT REFERENCES tax(id),
    flags INTEGER DEFAULT 0
);

-- Tax invoices (налоговые накладные)
CREATE TABLE IF NOT EXISTS tax_invoice (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(32) NOT NULL,
    dt DATE NOT NULL,
    ttype SMALLINT NOT NULL,  -- 0=SALE, 1=PURCHASE, 2=EXPORT, 3=ADJUSTMENT
    seller_id BIGINT NOT NULL REFERENCES person(id),
    buyer_id BIGINT NOT NULL REFERENCES person(id),
    bill_id BIGINT REFERENCES bill(id),
    amount NUMERIC(18,4) DEFAULT 0,
    vat NUMERIC(18,4) DEFAULT 0,
    total NUMERIC(18,4) DEFAULT 0,
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=ISSUED, 2=RECEIVED, 3=CANCELLED
    tax_period DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number, ttype)
);

-- Tax registers (налоговые регистры)
CREATE TABLE IF NOT EXISTS tax_register (
    id BIGSERIAL PRIMARY KEY,
    tax_id BIGINT NOT NULL REFERENCES tax(id),
    tax_period DATE NOT NULL,
    dt DATE NOT NULL,
    op_kind_id BIGINT REFERENCES op_kind(id),
    base_amount NUMERIC(18,4) DEFAULT 0,
    tax_amount NUMERIC(18,4) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tax declarations (налоговые декларации)
CREATE TABLE IF NOT EXISTS tax_declaration (
    id BIGSERIAL PRIMARY KEY,
    tax_id BIGINT NOT NULL REFERENCES tax(id),
    tax_period DATE NOT NULL,
    base_amount NUMERIC(18,4) DEFAULT 0,
    tax_amount NUMERIC(18,4) DEFAULT 0,
    vat_input NUMERIC(18,4) DEFAULT 0,
    vat_output NUMERIC(18,4) DEFAULT 0,
    vat_payable NUMERIC(18,4) DEFAULT 0,
    vat_refund NUMERIC(18,4) DEFAULT 0,
    status SMALLINT DEFAULT 0,
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tax_id, tax_period)
);

-- Индексы для налогов
CREATE INDEX IF NOT EXISTS idx_tax_name ON tax(name);
CREATE INDEX IF NOT EXISTS idx_tax_invoice_number ON tax_invoice(number);
CREATE INDEX IF NOT EXISTS idx_tax_invoice_dt ON tax_invoice(dt);
CREATE INDEX IF NOT EXISTS idx_tax_invoice_seller ON tax_invoice(seller_id);
CREATE INDEX IF NOT EXISTS idx_tax_invoice_buyer ON tax_invoice(buyer_id);
CREATE INDEX IF NOT EXISTS idx_tax_register_period ON tax_register(tax_period);
CREATE INDEX IF NOT EXISTS idx_tax_declaration_period ON tax_declaration(tax_period);

-- ============================================================
-- Функции для налогов
-- ============================================================

-- Расчёт НДС
CREATE OR REPLACE FUNCTION calc_vat(p_amount NUMERIC(18,4), p_rate NUMERIC(5,4))
RETURNS NUMERIC(18,4) AS $$
BEGIN
    IF p_rate = 0 THEN
        RETURN 0;
    END IF;
    RETURN p_amount * p_rate / (1 + p_rate);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Расчёт суммы без НДС
CREATE OR REPLACE FUNCTION calc_net_amount(p_amount_with_vat NUMERIC(18,4), p_rate NUMERIC(5,4))
RETURNS NUMERIC(18,4) AS $$
BEGIN
    IF p_rate = 0 THEN
        RETURN p_amount_with_vat;
    END IF;
    RETURN p_amount_with_vat / (1 + p_rate);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Расчёт НДС к уплате
CREATE OR REPLACE FUNCTION calc_vat_payable(p_vat_output NUMERIC(18,4), p_vat_input NUMERIC(18,4))
RETURNS NUMERIC(18,4) AS $$
BEGIN
    RETURN GREATEST(p_vat_output - p_vat_input, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Расчёт НДС к возмещению
CREATE OR REPLACE FUNCTION calc_vat_refund(p_vat_output NUMERIC(18,4), p_vat_input NUMERIC(18,4))
RETURNS NUMERIC(18,4) AS $$
BEGIN
    RETURN GREATEST(p_vat_input - p_vat_output, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Создание налоговой накладной
CREATE OR REPLACE FUNCTION create_tax_invoice(
    p_number VARCHAR(32),
    p_date DATE,
    p_type SMALLINT,
    p_seller_id BIGINT,
    p_buyer_id BIGINT,
    p_bill_id BIGINT,
    p_amount NUMERIC(18,4),
    p_rate NUMERIC(5,4)
) RETURNS BIGINT AS $$
DECLARE
    v_vat NUMERIC(18,4);
    v_id BIGINT;
BEGIN
    v_vat := calc_vat(p_amount, p_rate);
    
    INSERT INTO tax_invoice (number, dt, ttype, seller_id, buyer_id, bill_id, amount, vat, total, status)
    VALUES (p_number, p_date, p_type, p_seller_id, p_buyer_id, p_bill_id, p_amount, v_vat, p_amount + v_vat, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Налоговая декларация по НДС
CREATE OR REPLACE FUNCTION create_vat_declaration(
    p_tax_period DATE,
    p_base_amount NUMERIC(18,4),
    p_vat_input NUMERIC(18,4),
    p_vat_output NUMERIC(18,4)
) RETURNS BIGINT AS $$
DECLARE
    v_vat_payable NUMERIC(18,4);
    v_vat_refund NUMERIC(18,4);
    v_id BIGINT;
BEGIN
    v_vat_payable := calc_vat_payable(p_vat_output, p_vat_input);
    v_vat_refund := calc_vat_refund(p_vat_output, p_vat_input);
    
    INSERT INTO tax_declaration (tax_id, tax_period, base_amount, tax_amount, vat_input, vat_output, vat_payable, vat_refund, status)
    VALUES (1, p_tax_period, p_base_amount, v_vat_payable, p_vat_input, p_vat_output, v_vat_payable, v_vat_refund, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Налоговые накладные на продажу
CREATE OR REPLACE VIEW v_sales_tax_invoices AS
SELECT 
    ti.id,
    ti.number,
    ti.dt,
    ti.seller_id,
    ps.name AS seller_name,
    ti.buyer_id,
    pb.name AS buyer_name,
    ti.amount,
    ti.vat,
    ti.total,
    ti.status,
    ti.tax_period
FROM tax_invoice ti
JOIN person ps ON ps.id = ti.seller_id
JOIN person pb ON pb.id = ti.buyer_id
WHERE ti.ttype = 0  -- SALE
ORDER BY ti.dt DESC;

-- Налоговые накладные на покупку
CREATE OR REPLACE VIEW v_purchase_tax_invoices AS
SELECT 
    ti.id,
    ti.number,
    ti.dt,
    ti.seller_id,
    ps.name AS seller_name,
    ti.buyer_id,
    pb.name AS buyer_name,
    ti.amount,
    ti.vat,
    ti.total,
    ti.status,
    ti.tax_period
FROM tax_invoice ti
JOIN person ps ON ps.id = ti.seller_id
JOIN person pb ON pb.id = ti.buyer_id
WHERE ti.ttype = 1  -- PURCHASE
ORDER BY ti.dt DESC;

-- НДС к уплате/возмещению
CREATE OR REPLACE VIEW v_vat_summary AS
SELECT 
    td.tax_period,
    td.vat_input,
    td.vat_output,
    td.vat_payable,
    td.vat_refund,
    CASE 
        WHEN td.vat_payable > td.vat_refund THEN td.vat_payable - td.vat_refund
        ELSE 0
    END AS net_payable,
    CASE 
        WHEN td.vat_refund > td.vat_payable THEN td.vat_refund - td.vat_payable
        ELSE 0
    END AS net_refund
FROM tax_declaration td
ORDER BY td.tax_period DESC;

-- Регистр НДС (книги покупок/продаж)
CREATE OR REPLACE VIEW v_vat_register AS
SELECT 
    ti.dt,
    ti.number,
    ti.ttype,
    CASE ti.ttype WHEN 0 THEN ti.seller_id ELSE ti.buyer_id END AS counterparty_id,
    CASE ti.ttype WHEN 0 THEN ps.name ELSE pb.name END AS counterparty_name,
    ti.amount,
    ti.vat,
    ti.total,
    ti.tax_period
FROM tax_invoice ti
LEFT JOIN person ps ON ps.id = ti.seller_id
LEFT JOIN person pb ON pb.id = ti.buyer_id
WHERE ti.status IN (1, 2)  -- ISSUED или RECEIVED
ORDER BY ti.dt;