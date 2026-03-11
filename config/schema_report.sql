-- =================================================================
-- Report System - Отчёты и аналитика
-- =================================================================

-- Report (определения отчётов)
CREATE TABLE IF NOT EXISTS report (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    type SMALLINT NOT NULL DEFAULT 0,   -- 0=Table, 1=Chart, 2=Pivot, 3=CrossTab, 4=Label, 5=Barcode
    category SMALLINT NOT NULL DEFAULT 0, -- 0=Sales, 1=Warehouse, 2=Finance, 3=HR, 4=Production, 5=Analytics, 6=Tax
    query TEXT NOT NULL,                  -- SQL запрос
    flags INTEGER DEFAULT 0,              -- 1=Active, 2=AdminOnly, 4=Cached, 8=ParamsRequired
    owner_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_report_type ON report(type);
CREATE INDEX IF NOT EXISTS idx_report_category ON report(category);
CREATE INDEX IF NOT EXISTS idx_report_flags ON report(flags);

-- Report Parameter (параметры отчётов)
CREATE TABLE IF NOT EXISTS report_param (
    id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES report(id) ON DELETE CASCADE,
    name VARCHAR(256) NOT NULL,
    param_key VARCHAR(50) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,   -- 0=String, 1=Int, 2=Date, 3=DateRange, 4=Object, 5=List
    default_value TEXT,
    is_required BOOLEAN DEFAULT FALSE,
    param_order INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_report_param_report ON report_param(report_id);

-- Report Result (результаты отчётов)
CREATE TABLE IF NOT EXISTS report_result (
    id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES report(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL,
    params JSONB,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status SMALLINT NOT NULL DEFAULT 0, -- 0=Pending, 1=Running, 2=Completed, 3=Failed
    data JSONB,
    error TEXT
);

CREATE INDEX IF NOT EXISTS idx_report_result_report ON report_result(report_id);
CREATE INDEX IF NOT EXISTS idx_report_result_user ON report_result(user_id);
CREATE INDEX IF NOT EXISTS idx_report_result_status ON report_result(status);
CREATE INDEX IF NOT EXISTS idx_report_result_generated ON report_result(generated_at);

-- =================================================================
-- Default Reports (базовые отчёты)
-- =================================================================

INSERT INTO report (name, description, type, category, query, flags) VALUES
    ('Остатки товаров', 'Остатки товаров по складам', 0, 1, 
     'SELECT * FROM mv_current_stock', 5),
    ('Продажи за период', 'Продажи по дням', 0, 0,
     'SELECT * FROM get_sales_by_day($1, $2, $3)', 5),
    ('Дебиторская задолженность', 'Просроченная дебиторка', 0, 2,
     'SELECT * FROM mv_receivables', 5),
    ('Прибыльность товаров', 'Прибыльность по товарам', 0, 5,
     'SELECT * FROM get_goods_profitability($1, $2, $3)', 5)
ON CONFLICT DO NOTHING;

-- =================================================================
-- Functions
-- =================================================================

-- Queue report generation
CREATE OR REPLACE FUNCTION queue_report(BIGINT, BIGINT, JSONB)
RETURNS BIGINT AS $$
DECLARE
    p_report_id ALIAS FOR $1;
    p_user_id ALIAS FOR $2;
    p_params ALIAS FOR $3;
    v_result_id BIGINT;
BEGIN
    INSERT INTO report_result (report_id, user_id, params, status)
    VALUES (p_report_id, p_user_id, p_params, 0)  -- Pending
    RETURNING id INTO v_result_id;
    
    RETURN v_result_id;
END;
$$ LANGUAGE plpgsql;

-- Get report parameters
CREATE OR REPLACE FUNCTION get_report_params(BIGINT)
RETURNS TABLE (id BIGINT, name TEXT, param_key TEXT, type SMALLINT, 
               default_value TEXT, is_required BOOLEAN, param_order INT) AS $$
BEGIN
    RETURN QUERY
    SELECT rp.id, rp.name, rp.param_key, rp.type, rp.default_value, rp.is_required, rp.param_order
    FROM report_param rp
    WHERE rp.report_id = $1
    ORDER BY rp.param_order;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get user report history
CREATE OR REPLACE FUNCTION get_user_report_history(BIGINT, INT)
RETURNS TABLE (id BIGINT, report_name TEXT, generated_at TIMESTAMPTZ, 
               status SMALLINT, error TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT rr.id, r.name, rr.generated_at, rr.status, rr.error
    FROM report_result rr
    JOIN report r ON r.id = rr.report_id
    WHERE rr.user_id = $1
    ORDER BY rr.generated_at DESC
    LIMIT $2;
END;
$$ LANGUAGE plpgsql STABLE;

-- Mark report as running
CREATE OR REPLACE FUNCTION start_report(BIGINT)
RETURNS VOID AS $$
BEGIN
    UPDATE report_result SET status = 1 WHERE id = $1 AND status = 0;
END;
$$ LANGUAGE plpgsql;

-- Complete report
CREATE OR REPLACE FUNCTION complete_report(BIGINT, JSONB, TEXT)
RETURNS VOID AS $$
DECLARE
    p_result_id ALIAS FOR $1;
    p_data ALIAS FOR $2;
    p_error ALIAS FOR $3;
BEGIN
    UPDATE report_result
    SET status = CASE WHEN p_error IS NULL THEN 2 ELSE 3 END,
        data = p_data,
        error = p_error,
        generated_at = NOW()
    WHERE id = p_result_id;
END;
$$ LANGUAGE plpgsql;

-- =================================================================
-- Triggers
-- =================================================================

CREATE OR REPLACE FUNCTION update_report_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_report_update
    BEFORE UPDATE ON report
    FOR EACH ROW EXECUTE FUNCTION update_report_timestamp();

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE report IS 'Определения отчётов';
COMMENT ON TABLE report_param IS 'Параметры отчётов';
COMMENT ON TABLE report_result IS 'Результаты отчётов';
COMMENT ON report.type IS 'Тип: 0=Таблица, 1=График, 2=Сводная, 3=Кросс-таб, 4=Наклейки, 5=Штрихкоды';
COMMENT ON report.category IS 'Категория: 0=Продажи, 1=Склад, 2=Финансы, 3=Кадры, 4=Производство, 5=Аналитика, 6=Налоги';
