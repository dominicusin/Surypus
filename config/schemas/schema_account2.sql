-- =============================================================================
-- БУХГАЛТЕРСКИЕ СЧЁТА (v2)
-- Соответствуют Core.Accounting.Account2
-- Аналог: PPOBJ_ACCOUNT2
-- =============================================================================

CREATE TABLE IF NOT EXISTS account2 (
    id SERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    kind INT NOT NULL,  -- 1:Asset, 2:Liability, 3:Equity, 4:Revenue, 5:Expense
    parent_id INT DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_account2_code ON account2(code);
CREATE INDEX idx_account2_parent ON account2(parent_id);
CREATE INDEX idx_account2_kind ON account2(kind);

-- DEFAULT DATA: План счетов РФ
INSERT INTO account2 (id, code, name, kind, parent_id) VALUES
(1, '01', 'Основные средства', 1, 0),
(2, '02', 'Амортизация основных средств', 2, 1),
(3, '10', 'Материалы', 1, 0),
(4, '20', 'Основное производство', 1, 0),
(5, '41', 'Товары', 1, 0),
(6, '43', 'Готовая продукция', 1, 0),
(7, '50', 'Касса', 1, 0),
(8, '51', 'Расчётные счёта', 1, 0),
(9, '60', 'Расчёты с поставщиками', 2, 0),
(10, '62', 'Расчёты с покупателями', 2, 0),
(11, '66', 'Расчёты по кредитам', 2, 0),
(12, '68', 'Расчёты по налогам', 2, 0),
(13, '69', 'Расчёты по социальному страхованию', 2, 0),
(14, '70', 'Расчёты с персоналом по оплате труда', 2, 0),
(15, '80', 'Уставный капитал', 3, 0),
(16, '84', 'Нераспределённая прибыль', 3, 0),
(17, '90', 'Продажи', 4, 0),
(18, '91', 'Прочие доходы и расходы', 4, 0),
(19, '99', 'Прибыли и убытки', 3, 0)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_account2_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_account2_update
    BEFORE UPDATE ON account2
    FOR EACH ROW
    EXECUTE FUNCTION update_account2_timestamp();

-- VIEW: План счетов с иерархией
CREATE OR REPLACE VIEW v_account2_hierarchy AS
WITH RECURSIVE acc_hierarchy AS (
    SELECT 
        id,
        code,
        name,
        kind,
        parent_id,
        0 AS level,
        ARRAY[code] AS path
    FROM account2
    WHERE parent_id = 0
    
    UNION ALL
    
    SELECT 
        a.id,
        a.code,
        a.name,
        a.kind,
        a.parent_id,
        ah.level + 1,
        ah.path || a.code
    FROM account2 a
    JOIN acc_hierarchy ah ON ah.id = a.parent_id
)
SELECT * FROM acc_hierarchy
ORDER BY code;
