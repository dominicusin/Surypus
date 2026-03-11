-- =============================================================================
-- БУХГАЛТЕРСКИЕ ПРОВОДКИ
-- Соответствуют Core.Accounting.AccTurn
-- Аналог: PPOBJ_ACCTURN
-- =============================================================================

CREATE TABLE IF NOT EXISTS acc_turn (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL,
    acc_id INT NOT NULL,
    is_debit BOOLEAN DEFAULT TRUE,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    date DATE NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_acc_turn_bill ON acc_turn(bill_id);
CREATE INDEX idx_acc_turn_acc ON acc_turn(acc_id);
CREATE INDEX idx_acc_turn_date ON acc_turn(date);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_acc_turn_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_acc_turn_update
    BEFORE UPDATE ON acc_turn
    FOR EACH ROW
    EXECUTE FUNCTION update_acc_turn_timestamp();

-- VIEW: Обороты за период
CREATE OR REPLACE VIEW v_acc_turnover_period AS
SELECT 
    acc_id,
    a.code AS acc_code,
    a.name AS acc_name,
    SUM(CASE WHEN is_debit THEN amount ELSE 0 END) AS debit_turnover,
    SUM(CASE WHEN NOT is_debit THEN amount ELSE 0 END) AS credit_turnover,
    COUNT(*) AS operation_count
FROM acc_turn at
JOIN account a ON a.id = at.acc_id
GROUP BY acc_id, a.code, a.name;
