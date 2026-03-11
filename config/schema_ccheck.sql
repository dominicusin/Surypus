-- =============================================================================
-- КАССОВЫЕ ЧЕКИ
-- Соответствуют Core.Commerce.CCheck
-- Аналог: PPOBJ_CCHECK
-- =============================================================================

CREATE TABLE IF NOT EXISTS ccheck (
    id SERIAL PRIMARY KEY,
    session_id INT NOT NULL,
    number INT NOT NULL,
    cashier_id INT NOT NULL,
    person_id INT DEFAULT 0,
    total NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (total >= 0),
    discount NUMERIC(18,4) DEFAULT 0 CHECK (discount >= 0),
    flags INT DEFAULT 0,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    status INT DEFAULT 0,  -- 0:New, 1:Registered, 2:Printed, 3:Returned, 4:Error
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ccheck_session ON ccheck(session_id);
CREATE INDEX idx_ccheck_number ON ccheck(number);
CREATE INDEX idx_ccheck_date ON ccheck(date);
CREATE INDEX idx_ccheck_status ON ccheck(status);

CREATE TABLE IF NOT EXISTS ccheck_line (
    id SERIAL PRIMARY KEY,
    check_id INT NOT NULL REFERENCES ccheck(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) DEFAULT 0 CHECK (discount >= 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ccheck_line_check ON ccheck_line(check_id);
CREATE INDEX idx_ccheck_line_goods ON ccheck_line(goods_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_ccheck_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ccheck_update
    BEFORE UPDATE ON ccheck
    FOR EACH ROW
    EXECUTE FUNCTION update_ccheck_timestamp();

CREATE TRIGGER trigger_ccheck_line_update
    BEFORE UPDATE ON ccheck_line
    FOR EACH ROW
    EXECUTE FUNCTION update_ccheck_timestamp();

-- VIEW: Продажи по чекам
CREATE OR REPLACE VIEW v_check_sales AS
SELECT 
    cc.id,
    cc.session_id,
    cc.number,
    cc.date,
    cc.cashier_id,
    u.name AS cashier_name,
    cc.person_id,
    p.name AS person_name,
    cc.total,
    cc.discount,
    cc.status,
    CASE cc.status
        WHEN 0 THEN 'New'
        WHEN 1 THEN 'Registered'
        WHEN 2 THEN 'Printed'
        WHEN 3 THEN 'Returned'
        WHEN 4 THEN 'Error'
    END AS status_text
FROM ccheck cc
LEFT JOIN usr u ON u.id = cc.cashier_id
LEFT JOIN person p ON p.id = cc.person_id
WHERE cc.status IN (1, 2)  -- Registered или Printed
ORDER BY cc.date DESC;
