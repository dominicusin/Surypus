-- =============================================================================
-- БУХГАЛТЕРСКИЕ СВЯЗКИ
-- Соответствуют Core.Accounting.AccRel
-- Аналог: PPOBJ_ACCTREL
-- =============================================================================

CREATE TABLE IF NOT EXISTS acc_rel (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL,
    acc_id INT NOT NULL,
    is_debit BOOLEAN DEFAULT TRUE,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_acc_rel_bill ON acc_rel(bill_id);
CREATE INDEX idx_acc_rel_acc ON acc_rel(acc_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_acc_rel_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_acc_rel_update
    BEFORE UPDATE ON acc_rel
    FOR EACH ROW
    EXECUTE FUNCTION update_acc_rel_timestamp();

-- VIEW: Обороты по счетам
CREATE OR REPLACE VIEW v_acc_turnover AS
SELECT 
    acc_id,
    SUM(CASE WHEN is_debit THEN amount ELSE 0 END) AS debit_sum,
    SUM(CASE WHEN NOT is_debit THEN amount ELSE 0 END) AS credit_sum,
    COUNT(*) AS operation_count
FROM acc_rel
GROUP BY acc_id;
