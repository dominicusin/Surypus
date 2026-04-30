-- =============================================================================
-- РАЗМЕРНОСТЬ РАСЧЕТА ДОЛГОВ
-- Соответствуют Core.Accounting.DebtDimension
-- Аналог: PPOBJ_DEBTDIM
-- =============================================================================

CREATE TABLE IF NOT EXISTS debt_dimension (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INT DEFAULT 0,
    grace_period INT DEFAULT 0,  -- Льготный период в днях
    warn_period INT DEFAULT 0,   -- Период предупреждения в днях
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO debt_dimension (id, name, grace_period, warn_period) VALUES
(1, 'По документам', 0, 0),
(2, 'По оплате', 0, 0),
(3, 'С льготным периодом 30 дней', 30, 7),
(4, 'С льготным периодом 60 дней', 60, 14),
(5, 'С льготным периодом 90 дней', 90, 21)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_debt_dimension_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_debt_dimension_update
    BEFORE UPDATE ON debt_dimension
    FOR EACH ROW
    EXECUTE FUNCTION update_debt_dimension_timestamp();

-- FUNCTION: Определить статус просрочки
CREATE OR REPLACE FUNCTION get_debt_status(p_debt_dimension_id INT, p_days_overdue INT)
RETURNS TEXT AS $$
DECLARE
    v_grace_period INT;
    v_warn_period INT;
    v_status TEXT;
BEGIN
    SELECT grace_period, warn_period INTO v_grace_period, v_warn_period
    FROM debt_dimension WHERE id = p_debt_dimension_id;
    
    IF p_days_overdue <= v_grace_period THEN
        v_status := 'OK';
    ELSIF p_days_overdue <= v_grace_period + v_warn_period THEN
        v_status := 'WARNING';
    ELSE
        v_status := 'OVERDUE';
    END IF;
    
    RETURN v_status;
END;
$$ LANGUAGE plpgsql;
