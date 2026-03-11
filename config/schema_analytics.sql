-- =============================================================================
-- АНАЛИТИКА И ОТЧЁТЫ (Analytics)
-- Соответствуют Core.Analytics.Analytics
-- =============================================================================

-- Таблица товарооборота (для аналитики)
CREATE TABLE IF NOT EXISTS turnover_analytics (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    warehouse_id INT,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    income_qty NUMERIC(15,4) DEFAULT 0,
    income_sum NUMERIC(15,2) DEFAULT 0,
    outcome_qty NUMERIC(15,4) DEFAULT 0,
    outcome_sum NUMERIC(15,2) DEFAULT 0,
    rest_qty NUMERIC(15,4) DEFAULT 0,
    rest_sum NUMERIC(15,2) DEFAULT 0,
    cost_sum NUMERIC(15,2) DEFAULT 0,
    price_sum NUMERIC(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_turnover_analytics_goods ON turnover_analytics(goods_id);
CREATE INDEX idx_turnover_analytics_period ON turnover_analytics(period_start, period_end);

-- Таблица прибыльности
CREATE TABLE IF NOT EXISTS profitability_analytics (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    quantity NUMERIC(15,4) DEFAULT 0,
    cost_sum NUMERIC(15,2) DEFAULT 0,
    revenue_sum NUMERIC(15,2) DEFAULT 0,
    profit NUMERIC(15,2) DEFAULT 0,
    margin NUMERIC(5,2) DEFAULT 0,
    rentability NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_profitability_analytics_goods ON profitability_analytics(goods_id);

-- Таблица задолженности
CREATE TABLE IF NOT EXISTS debt_analytics (
    id SERIAL PRIMARY KEY,
    party_id INT NOT NULL,
    kind VARCHAR(20) NOT NULL,  -- 'RECEIVABLE' or 'PAYABLE'
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    debt NUMERIC(15,2) DEFAULT 0,
    days_overdue INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_debt_analytics_party ON debt_analytics(party_id);
CREATE INDEX idx_debt_analytics_kind ON debt_analytics(kind);

-- Таблица оборачиваемости
CREATE TABLE IF NOT EXISTS inventory_turnover_analytics (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    warehouse_id INT,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    avg_rest NUMERIC(15,4) DEFAULT 0,
    turnover NUMERIC(15,2) DEFAULT 0,
    days NUMERIC(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inventory_turnover_goods ON inventory_turnover_analytics(goods_id);

-- ABC-анализ
CREATE TABLE IF NOT EXISTS abc_analysis (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    revenue NUMERIC(15,2) DEFAULT 0,
    revenue_pct NUMERIC(5,2) DEFAULT 0,
    cumulative_pct NUMERIC(5,2) DEFAULT 0,
    category CHAR(1) CHECK (category IN ('A', 'B', 'C')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_abc_analysis_goods ON abc_analysis(goods_id);
CREATE INDEX idx_abc_analysis_category ON abc_analysis(category);

-- Функция расчёта товарооборота
CREATE OR REPLACE FUNCTION calc_turnover_analytics(
    p_goods_id INT,
    p_warehouse_id INT,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS TABLE(
    income_qty NUMERIC,
    income_sum NUMERIC,
    outcome_qty NUMERIC,
    outcome_sum NUMERIC,
    rest_qty NUMERIC,
    rest_sum NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE WHEN bl.bill_id IN (
            SELECT id FROM bills WHERE op_id = 1  -- Приход
        ) THEN bl.quantity ELSE 0 END), 0) AS income_qty,
        COALESCE(SUM(CASE WHEN bl.bill_id IN (
            SELECT id FROM bills WHERE op_id = 1
        ) THEN bl.quantity * bl.cost ELSE 0 END), 0) AS income_sum,
        COALESCE(SUM(CASE WHEN bl.bill_id IN (
            SELECT id FROM bills WHERE op_id = 2  -- Расход
        ) THEN bl.quantity ELSE 0 END), 0) AS outcome_qty,
        COALESCE(SUM(CASE WHEN bl.bill_id IN (
            SELECT id FROM bills WHERE op_id = 2
        ) THEN bl.quantity * bl.price ELSE 0 END), 0) AS outcome_sum,
        0 AS rest_qty,
        0 AS rest_sum
    FROM bill_lines bl
    JOIN bills b ON bl.bill_id = b.id
    WHERE bl.goods_id = p_goods_id
      AND b.dt BETWEEN p_period_start AND p_period_end
      AND (p_warehouse_id IS NULL OR bl.warehouse_id = p_warehouse_id);
END;
$$ LANGUAGE plpgsql;

-- Функция расчёта прибыльности
CREATE OR REPLACE FUNCTION calc_profitability_analytics(
    p_goods_id INT,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS TABLE(
    quantity NUMERIC,
    cost_sum NUMERIC,
    revenue_sum NUMERIC,
    profit NUMERIC,
    margin NUMERIC,
    rentability NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(bl.quantity), 0) AS quantity,
        COALESCE(SUM(bl.quantity * bl.cost), 0) AS cost_sum,
        COALESCE(SUM(bl.quantity * bl.price), 0) AS revenue_sum,
        COALESCE(SUM(bl.quantity * (bl.price - bl.cost)), 0) AS profit,
        CASE 
            WHEN COALESCE(SUM(bl.quantity * bl.price), 0) > 0 
            THEN (COALESCE(SUM(bl.quantity * bl.price), 0) - COALESCE(SUM(bl.quantity * bl.cost), 0)) 
                 / COALESCE(SUM(bl.quantity * bl.price), 0) * 100
            ELSE 0 
        END AS margin,
        CASE 
            WHEN COALESCE(SUM(bl.quantity * bl.cost), 0) > 0 
            THEN (COALESCE(SUM(bl.quantity * (bl.price - bl.cost)), 0)) 
                 / COALESCE(SUM(bl.quantity * bl.cost), 0) * 100
            ELSE 0 
        END AS rentability
    FROM bill_lines bl
    JOIN bills b ON bl.bill_id = b.id
    WHERE bl.goods_id = p_goods_id
      AND b.dt BETWEEN p_period_start AND p_period_end
      AND b.op_id = 2;  -- Только продажи
END;
$$ LANGUAGE plpgsql;

-- Функция ABC-анализа
CREATE OR REPLACE FUNCTION run_abc_analysis(
    p_period_start DATE,
    p_period_end DATE
)
RETURNS VOID AS $$
BEGIN
    -- Создаём временную таблицу с выручкой
    CREATE TEMP TABLE IF NOT EXISTS temp_abc AS
    SELECT 
        bl.goods_id,
        SUM(bl.quantity * bl.price) AS revenue
    FROM bill_lines bl
    JOIN bills b ON bl.bill_id = b.id
    WHERE b.dt BETWEEN p_period_start AND p_period_end
      AND b.op_id = 2
    GROUP BY bl.goods_id;
    
    -- Рассчитываем проценты
    INSERT INTO abc_analysis (goods_id, period_start, period_end, revenue, revenue_pct, cumulative_pct, category)
    SELECT 
        goods_id,
        p_period_start,
        p_period_end,
        revenue,
        revenue * 100.0 / NULLIF(SUM(revenue) OVER(), 0),
        0.0,  -- будет обновлено
        'C'  -- будет обновлено
    FROM temp_abc
    ORDER BY revenue DESC;
    
    -- Обновляем накопительный процент и категорию
    UPDATE abc_analysis aa
    SET 
        cumulative_pct = sub.cumulative,
        category = CASE 
            WHEN sub.cumulative <= 80 THEN 'A'
            WHEN sub.cumulative <= 95 THEN 'B'
            ELSE 'C'
        END
    FROM (
        SELECT 
            id,
            SUM(revenue_pct) OVER (ORDER BY revenue DESC) AS cumulative
        FROM abc_analysis
        WHERE period_start = p_period_start AND period_end = p_period_end
    ) sub
    WHERE aa.id = sub.id;
    
    DROP TABLE IF EXISTS temp_abc;
END;
$$ LANGUAGE plpgsql;
