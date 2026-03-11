-- =================================================================
-- Quotation System - Котировки и прайс-листы
-- =================================================================
-- Analog: OpenPapyrus pplib/quot.cpp, objquotk.cpp (PPObjQuotKind)

-- Quotation Kind (виды котировок)
CREATE TABLE IF NOT EXISTS quotation_kind (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(20),
    class SMALLINT NOT NULL DEFAULT 0,  -- PPQuot::clsXXX
    flags INTEGER DEFAULT 0,             -- QKF_XXX
    acc_sheet_id BIGINT,                 -- План счетов
    base_qk_id BIGINT,                   -- Базовая котировка
    formula VARCHAR(50),                 -- Формула: COST+QUOT, MARGIN, MARKUP
    lower_bound NUMERIC(18,4),           -- Нижняя граница
    upper_bound NUMERIC(18,4),           -- Верхняя граница
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotation_kind_symb ON quotation_kind(symb) WHERE symb IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_quotation_kind_class ON quotation_kind(class);

-- Quotation (котировки)
CREATE TABLE IF NOT EXISTS quotation (
    id BIGSERIAL PRIMARY KEY,
    kind_id BIGINT NOT NULL REFERENCES quotation_kind(id),
    goods_id BIGINT NOT NULL,
    location_id BIGINT,                  -- NULL = все склады
    agent_id BIGINT,                     -- Контрагент
    quot NUMERIC(18,4) NOT NULL,         -- Значение
    lower_bound NUMERIC(18,4),           -- Нижняя граница кол-ва
    upper_bound NUMERIC(18,4),           -- Верхняя граница кол-ва
    dt DATE NOT NULL,                    -- Дата действия
    expiry_date DATE,                    -- Срок действия
    flags INTEGER DEFAULT 0,             -- QTF_XXX
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotation_kind ON quotation(kind_id);
CREATE INDEX IF NOT EXISTS idx_quotation_goods ON quotation(goods_id);
CREATE INDEX IF NOT EXISTS idx_quotation_location ON quotation(location_id);
CREATE INDEX IF NOT EXISTS idx_quotation_dt ON quotation(dt);
CREATE INDEX IF NOT EXISTS idx_quotation_expiry ON quotation(expiry_date) WHERE expiry_date IS NOT NULL;

-- Composite index for actual quotation lookup
CREATE INDEX IF NOT EXISTS idx_quotation_actual ON quotation(goods_id, kind_id, dt, expiry_date) 
    WHERE flags & 1 = 1;

-- =================================================================
-- Default Quotation Kinds (базовые виды котировок)
-- =================================================================

INSERT INTO quotation_kind (name, symb, class, flags, formula) VALUES
    ('Закупочная', 'COST', 1, 5, 'COST+QUOT'),        -- Supplier, read-only
    ('Оптовая', 'WHOLE', 3, 0, 'MARKUP'),
    ('Розничная', 'RETAIL', 2, 0, 'MARKUP'),
    ('Минимальная розничная', 'MINRETAIL', 2, 1, NULL), -- Read-only
    ('Специальная поставщика', 'SUPPL', 1, 0, 'COST+QUOT'),
    ('Акция', 'PROMO', 4, 16, NULL),                  -- Period
    ('Контрагентская', 'CLIENT', 5, 0, NULL)
ON CONFLICT DO NOTHING;

-- =================================================================
-- Functions
-- =================================================================

-- Get actual quotation for goods on date
CREATE OR REPLACE FUNCTION get_actual_quotation(BIGINT, BIGINT, DATE)
RETURNS TABLE (id BIGINT, kind_id BIGINT, goods_id BIGINT, location_id BIGINT,
               quot NUMERIC(18,4), dt DATE, expiry_date DATE) AS $$
BEGIN
    RETURN QUERY
    SELECT q.id, q.kind_id, q.goods_id, q.location_id,
           q.quot, q.dt, q.expiry_date
    FROM quotation q
    WHERE q.goods_id = $1
      AND q.kind_id = $2
      AND q.dt <= $3
      AND (q.expiry_date IS NULL OR q.expiry_date >= $3)
      AND q.flags & 1 = 1  -- Active
    ORDER BY q.dt DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get all actual quotations for goods
CREATE OR REPLACE FUNCTION get_goods_quotations(BIGINT, DATE)
RETURNS TABLE (kind_id BIGINT, kind_name TEXT, quot NUMERIC(18,4),
               lower_bound NUMERIC(18,4), upper_bound NUMERIC(18,4),
               dt DATE, expiry_date DATE) AS $$
BEGIN
    RETURN QUERY
    SELECT q.kind_id, qk.name, q.quot, q.lower_bound, q.upper_bound,
           q.dt, q.expiry_date
    FROM quotation q
    JOIN quotation_kind qk ON qk.id = q.kind_id
    WHERE q.goods_id = $1
      AND q.dt <= $2
      AND (q.expiry_date IS NULL OR q.expiry_date >= $2)
      AND q.flags & 1 = 1
    ORDER BY qk.name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate price with quotation
CREATE OR REPLACE FUNCTION calculate_price(BIGINT, BIGINT, NUMERIC(18,4), DATE)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    p_goods_id ALIAS FOR $1;
    p_kind_id ALIAS FOR $2;
    p_cost ALIAS FOR $3;
    p_date ALIAS FOR $4;
    v_quot NUMERIC(18,4);
    v_formula VARCHAR(50);
BEGIN
    -- Get actual quotation
    SELECT q.quot, qk.formula INTO v_quot, v_formula
    FROM quotation q
    JOIN quotation_kind qk ON qk.id = q.kind_id
    WHERE q.goods_id = p_goods_id
      AND q.kind_id = p_kind_id
      AND q.dt <= p_date
      AND (q.expiry_date IS NULL OR q.expiry_date >= p_date)
      AND q.flags & 1 = 1
    ORDER BY q.dt DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN p_cost;  -- No quotation, return cost
    END IF;
    
    -- Calculate based on formula
    IF v_formula IS NULL OR v_formula = 'COST+QUOT' THEN
        RETURN p_cost + v_quot;
    ELSIF v_formula = 'MARKUP' THEN
        RETURN p_cost * (1 + v_quot / 100);
    ELSIF v_formula = 'MARGIN' THEN
        RETURN p_cost + (p_cost - p_cost) * v_quot / 100;  -- Simplified
    END IF;
    
    RETURN p_cost + v_quot;
END;
$$ LANGUAGE plpgsql STABLE;

-- =================================================================
-- Triggers
-- =================================================================

CREATE OR REPLACE FUNCTION update_quotation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_quotation_kind_update
    BEFORE UPDATE ON quotation_kind
    FOR EACH ROW EXECUTE FUNCTION update_quotation_timestamp();

CREATE TRIGGER tr_quotation_update
    BEFORE UPDATE ON quotation
    FOR EACH ROW EXECUTE FUNCTION update_quotation_timestamp();

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE quotation_kind IS 'Виды котировок (аналог QuotKindTbl)';
COMMENT ON TABLE quotation IS 'Котировки (аналог PPQuot)';
COMMENT ON quotation_kind.class IS 'Класс: 0=Общая, 1=Поставщика, 2=Розничная, 3=Оптовая, 4=Специальная, 5=Контрагентская';
COMMENT ON quotation_kind.flags IS 'Флаги: 1=Сумма, 2=Процент, 4=Только чтение, 8=Автозагрузка, 16=Период, 32=Специальная';
COMMENT ON quotation.flags IS 'Флаги: 1=Активна, 2=Валютная';
