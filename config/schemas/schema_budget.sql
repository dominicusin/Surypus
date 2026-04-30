-- =============================================================================
-- БЮДЖЕТЫ
-- Соответствуют Core.Finance.Budget
-- Аналог: PPOBJ_BUDGET
-- =============================================================================

CREATE TABLE IF NOT EXISTS budget (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_amount NUMERIC(18,4) DEFAULT 0 CHECK (total_amount >= 0),
    status INT DEFAULT 0,  -- 0:Draft, 1:Approved, 2:Active, 3:Closed, 4:Cancelled
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_budget_dates CHECK (period_start <= period_end)
);

CREATE INDEX idx_budget_period ON budget(period_start, period_end);
CREATE INDEX idx_budget_status ON budget(status);

CREATE TABLE IF NOT EXISTS budget_item (
    id SERIAL PRIMARY KEY,
    budget_id INT NOT NULL REFERENCES budget(id) ON DELETE CASCADE,
    account_id INT NOT NULL,
    plan_amount NUMERIC(18,4) DEFAULT 0 CHECK (plan_amount >= 0),
    fact_amount NUMERIC(18,4) DEFAULT 0 CHECK (fact_amount >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_budget_item_budget ON budget_item(budget_id);
CREATE INDEX idx_budget_item_account ON budget_item(account_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_budget_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_budget_update
    BEFORE UPDATE ON budget
    FOR EACH ROW
    EXECUTE FUNCTION update_budget_timestamp();

CREATE TRIGGER trigger_budget_item_update
    BEFORE UPDATE ON budget_item
    FOR EACH ROW
    EXECUTE FUNCTION update_budget_timestamp();

-- VIEW: Исполнение бюджета
CREATE OR REPLACE VIEW v_budget_execution AS
SELECT 
    b.id AS budget_id,
    b.name AS budget_name,
    b.period_start,
    b.period_end,
    bi.account_id,
    a.code AS account_code,
    a.name AS account_name,
    bi.plan_amount,
    bi.fact_amount,
    (bi.plan_amount - bi.fact_amount) AS deviation,
    CASE 
        WHEN bi.plan_amount = 0 THEN 0
        ELSE ROUND((bi.fact_amount / bi.plan_amount) * 100, 2)
    END AS execution_pct
FROM budget b
JOIN budget_item bi ON bi.budget_id = b.id
JOIN account a ON a.id = bi.account_id
WHERE b.status IN (1, 2)  -- Approved или Active
ORDER BY b.period_start, a.code;