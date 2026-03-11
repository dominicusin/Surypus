-- =============================================================================
-- ДОКУМЕНТЫ
-- Соответствуют Core.Document.Bill
-- Аналог: PPOBJ_BILL
-- =============================================================================

CREATE TABLE IF NOT EXISTS bill (
    id SERIAL PRIMARY KEY,
    number VARCHAR(32) NOT NULL,
    date DATE NOT NULL,
    op_kind_id INT NOT NULL,
    op_counter_id INT DEFAULT 0,
    object_id INT DEFAULT 0,
    amount NUMERIC(18,4) DEFAULT 0 CHECK (amount >= 0),
    vat_rate NUMERIC(5,2) DEFAULT 0,
    vat_sum NUMERIC(18,4) DEFAULT 0,
    currency_id INT DEFAULT 1,
    rate NUMERIC(18,8) DEFAULT 1,
    flags INT DEFAULT 0,
    edi_status INT DEFAULT 0,
    edi_conf_status INT DEFAULT 0,
    status INT DEFAULT 0,  -- 0:New, 1:Posted, 2:Archived
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bill_number ON bill(number);
CREATE INDEX idx_bill_date ON bill(date);
CREATE INDEX idx_bill_op_kind ON bill(op_kind_id);
CREATE INDEX idx_bill_object ON bill(object_id);
CREATE INDEX idx_bill_status ON bill(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_bill_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_bill_update
    BEFORE UPDATE ON bill
    FOR EACH ROW
    EXECUTE FUNCTION update_bill_timestamp();

-- TABLE: Строки документа
CREATE TABLE IF NOT EXISTS bill_line (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL REFERENCES bill(id) ON DELETE CASCADE,
    line_num INT NOT NULL,
    goods_id INT NOT NULL,
    quantity NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0,
    vat_rate NUMERIC(5,2) DEFAULT 0,
    amount NUMERIC(18,4) DEFAULT 0,
    vat_amount NUMERIC(18,4) DEFAULT 0,
    line_total NUMERIC(18,4) DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bill_line_bill ON bill_line(bill_id);
CREATE INDEX idx_bill_line_goods ON bill_line(goods_id);

-- VIEW: Документы с суммами
CREATE OR REPLACE VIEW v_bills_with_amounts AS
SELECT 
    b.id,
    b.number,
    b.date,
    b.op_kind_id,
    ok.name AS op_kind_name,
    b.amount,
    b.vat_rate,
    b.vat_sum,
    b.currency_id,
    b.status,
    CASE b.status
        WHEN 0 THEN 'New'
        WHEN 1 THEN 'Posted'
        WHEN 2 THEN 'Archived'
    END AS status_text
FROM bill b
JOIN op_kind ok ON ok.id = b.op_kind_id
ORDER BY b.date DESC, b.number;
