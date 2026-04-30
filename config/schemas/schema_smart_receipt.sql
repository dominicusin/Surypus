-- =============================================================================
-- SMART-ЧЕКИ
-- Соответствуют Core.Receipt.SmartReceipt
-- Аналог: PPOBJ_CHKINP
-- =============================================================================

CREATE TABLE IF NOT EXISTS smart_receipt (
    id SERIAL PRIMARY KEY,
    session_id INT NOT NULL,
    pos_id INT NOT NULL,
    fiscal_number VARCHAR(64),
    total NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (total >= 0),
    status INT DEFAULT 0,  -- 0:Pending, 1:Printed, 2:Sent, 3:Error
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_smart_receipt_session ON smart_receipt(session_id);
CREATE INDEX idx_smart_receipt_pos ON smart_receipt(pos_id);
CREATE INDEX idx_smart_receipt_fiscal ON smart_receipt(fiscal_number);
CREATE INDEX idx_smart_receipt_status ON smart_receipt(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_smart_receipt_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_smart_receipt_update
    BEFORE UPDATE ON smart_receipt
    FOR EACH ROW
    EXECUTE FUNCTION update_smart_receipt_timestamp();

-- VIEW: Статистика смарт-чеков
CREATE OR REPLACE VIEW v_smart_receipt_stats AS
SELECT 
    sr.pos_id,
    p.name AS pos_name,
    COUNT(sr.id) AS total_receipts,
    COUNT(CASE WHEN sr.status = 1 THEN 1 END) AS printed,
    COUNT(CASE WHEN sr.status = 2 THEN 1 END) AS sent,
    COUNT(CASE WHEN sr.status = 3 THEN 1 END) AS errors,
    SUM(sr.total) AS total_sum
FROM smart_receipt sr
JOIN pos p ON p.id = sr.pos_id
GROUP BY sr.pos_id, p.name;
