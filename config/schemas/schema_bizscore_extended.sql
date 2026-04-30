-- ============================================================================
-- SCHEMA: Business Score (Бизнес-показатели)
-- Соответствует C++ классам BizScoreCore в objbizsc.cpp
-- ============================================================================

-- Таблица шаблонов бизнес-показателей
CREATE TABLE IF NOT EXISTS bizscore_template (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    category        VARCHAR(50) NOT NULL,    -- FINANCIAL, OPERATIONAL, MARKETING, HR, SALES, INVENTORY
    description     TEXT,
    formula         TEXT NOT NULL,           -- Формула расчёта
    target_value    DECIMAL(18,6) NOT NULL,  -- Целевое значение
    min_value       DECIMAL(18,6) DEFAULT 0,
    max_value       DECIMAL(18,6),
    unit            VARCHAR(50),
    weight          DECIMAL(5,4) DEFAULT 1.0,  -- Вес в агрегированном показателе
    comparison_type VARCHAR(20) DEFAULT 'HIGHER_BETTER',  -- HIGHER_BETTER, LOWER_BETTER, RANGE, TARGET
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT bst_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT bst_weight_range CHECK (weight >= 0 AND weight <= 1),
    CONSTRAINT bst_min_max_check CHECK (min_value <= target_value),
    CONSTRAINT bst_target_max_check CHECK (target_value <= COALESCE(max_value, target_value * 2))
);

-- Таблица значений бизнес-показателей
CREATE TABLE IF NOT EXISTS bizscore_value (
    id              SERIAL PRIMARY KEY,
    template_id     INTEGER NOT NULL REFERENCES bizscore_template(id) ON DELETE CASCADE,
    value           DECIMAL(18,6) NOT NULL,
    period_start    DATE NOT NULL,
    period_end      DATE NOT NULL,
    object_type     INTEGER,                 -- Тип объекта (PPOBJ_PERSON, PPOBJ_GOODS и т.д.)
    object_id       INTEGER,                 -- ID объекта
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT bsv_template_fk FOREIGN KEY (template_id) REFERENCES bizscore_template(id),
    CONSTRAINT bsv_period_check CHECK (period_start <= period_end),
    CONSTRAINT bsv_unique_value UNIQUE (template_id, period_start, period_end, object_type, object_id)
);

-- Таблица оценок достижения целей
CREATE TABLE IF NOT EXISTS bizscore_assessment (
    id              SERIAL PRIMARY KEY,
    template_id     INTEGER NOT NULL REFERENCES bizscore_template(id) ON DELETE CASCADE,
    object_type     INTEGER,
    object_id       INTEGER,
    period          DATE NOT NULL,
    actual_value    DECIMAL(18,6) NOT NULL,
    target_value    DECIMAL(18,6) NOT NULL,
    achievement_pct DECIMAL(7,2),            -- Процент достижения
    status          VARCHAR(20) NOT NULL,    -- EXCELLENT, GOOD, SATISFACTORY, POOR, CRITICAL
    trend           VARCHAR(20),             -- TRENDING_UP, TRENDING_DOWN, STABLE
    score           DECIMAL(5,2),            -- Оценка (0-100)
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT bsa_template_fk FOREIGN KEY (template_id) REFERENCES bizscore_template(id),
    CONSTRAINT bsa_achievement_check CHECK (achievement_pct >= 0),
    CONSTRAINT bsa_score_check CHECK (score >= 0 AND score <= 100)
);

-- Таблица глобальных показателей (агрегированных)
CREATE TABLE IF NOT EXISTS bizscore_global (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL,        -- ID пользователя/подразделения
    period          DATE NOT NULL,
    total_score     DECIMAL(5,2) NOT NULL,   -- Общий балл (0-100)
    rank            INTEGER,
    components      JSONB,                   -- JSON массив компонентов
    details         JSONB,                   -- Детальная информация
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT bsg_user_period_unique UNIQUE (user_id, period),
    CONSTRAINT bsg_total_score_range CHECK (total_score >= 0 AND total_score <= 100),
    CONSTRAINT bsg_rank_positive CHECK (rank IS NULL OR rank > 0)
);

-- Таблица истории изменений показателей
CREATE TABLE IF NOT EXISTS bizscore_history (
    id              SERIAL PRIMARY KEY,
    template_id     INTEGER NOT NULL REFERENCES bizscore_template(id) ON DELETE CASCADE,
    object_type     INTEGER,
    object_id       INTEGER,
    period          DATE NOT NULL,
    old_value       DECIMAL(18,6),
    new_value       DECIMAL(18,6) NOT NULL,
    change_pct      DECIMAL(7,2),
    changed_by      INTEGER,
    changed_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT bsh_template_fk FOREIGN KEY (template_id) REFERENCES bizscore_template(id)
);

-- Индексы для оптимизации
CREATE INDEX IF NOT EXISTS idx_bsv_template_period ON bizscore_value(template_id, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_bsv_object ON bizscore_value(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_bsa_object_period ON bizscore_assessment(object_type, object_id, period);
CREATE INDEX IF NOT EXISTS idx_bsg_user_period ON bizscore_global(user_id, period DESC);
CREATE INDEX IF NOT EXISTS idx_bsh_template ON bizscore_history(template_id, period);

-- Функция: Рассчитать ROI
CREATE OR REPLACE FUNCTION calculate_roi(p_income DECIMAL, p_investment DECIMAL)
RETURNS DECIMAL(7,2) AS $$
BEGIN
    IF p_investment = 0 THEN
        RETURN 0;
    END IF;
    RETURN ((p_income - p_investment) / p_investment) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать ROE
CREATE OR REPLACE FUNCTION calculate_roe(p_net_income DECIMAL, p_equity DECIMAL)
RETURNS DECIMAL(7,2) AS $$
BEGIN
    IF p_equity = 0 THEN
        RETURN 0;
    END IF;
    RETURN (p_net_income / p_equity) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать ROS
CREATE OR REPLACE FUNCTION calculate_ros(p_profit DECIMAL, p_revenue DECIMAL)
RETURNS DECIMAL(7,2) AS $$
BEGIN
    IF p_revenue = 0 THEN
        RETURN 0;
    END IF;
    RETURN (p_profit / p_revenue) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать оборачиваемость запасов
CREATE OR REPLACE FUNCTION calculate_inventory_turnover(p_cogs DECIMAL, p_avg_inventory DECIMAL)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    IF p_avg_inventory = 0 THEN
        RETURN 0;
    END IF;
    RETURN p_cogs / p_avg_inventory;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать коэффициент текущей ликвидности
CREATE OR REPLACE FUNCTION calculate_current_ratio(p_current_assets DECIMAL, p_current_liabilities DECIMAL)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    IF p_current_liabilities = 0 THEN
        RETURN 0;
    END IF;
    RETURN p_current_assets / p_current_liabilities;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать коэффициент быстрой ликвидности
CREATE OR REPLACE FUNCTION calculate_quick_ratio(
    p_current_assets DECIMAL, 
    p_inventory DECIMAL, 
    p_current_liabilities DECIMAL
)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    IF p_current_liabilities = 0 THEN
        RETURN 0;
    END IF;
    RETURN (p_current_assets - p_inventory) / p_current_liabilities;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Определить статус достижения цели
CREATE OR REPLACE FUNCTION get_achievement_status(
    p_achievement_pct DECIMAL,
    p_comparison_type VARCHAR(20)
)
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE 
        WHEN p_comparison_type = 'HIGHER_BETTER' THEN
            CASE 
                WHEN p_achievement_pct >= 100 THEN 'EXCELLENT'
                WHEN p_achievement_pct >= 80 THEN 'GOOD'
                WHEN p_achievement_pct >= 60 THEN 'SATISFACTORY'
                WHEN p_achievement_pct >= 40 THEN 'POOR'
                ELSE 'CRITICAL'
            END
        WHEN p_comparison_type = 'LOWER_BETTER' THEN
            CASE 
                WHEN p_achievement_pct <= 80 THEN 'EXCELLENT'
                WHEN p_achievement_pct <= 100 THEN 'GOOD'
                WHEN p_achievement_pct <= 120 THEN 'SATISFACTORY'
                WHEN p_achievement_pct <= 150 THEN 'POOR'
                ELSE 'CRITICAL'
            END
        ELSE 'SATISFACTORY'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Процедура: Рассчитать и сохранить оценку показателя
CREATE OR REPLACE PROCEDURE calculate_and_save_assessment(
    p_template_id INTEGER,
    p_object_type INTEGER,
    p_object_id INTEGER,
    p_period DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_actual_value DECIMAL(18,6);
    v_target_value DECIMAL(18,6);
    v_achievement_pct DECIMAL(7,2);
    v_comparison_type VARCHAR(20);
    v_status VARCHAR(20);
    v_trend VARCHAR(20);
    v_score DECIMAL(5,2);
BEGIN
    -- Получить фактическое и целевое значение
    SELECT bsv.value, bst.target_value, bst.comparison_type
    INTO v_actual_value, v_target_value, v_comparison_type
    FROM bizscore_value bsv
    JOIN bizscore_template bst ON bst.id = bsv.template_id
    WHERE bsv.template_id = p_template_id
      AND bsv.object_type = p_object_type
      AND bsv.object_id = p_object_id
      AND bsv.period_start <= p_period
      AND bsv.period_end >= p_period;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Рассчитать процент достижения
    IF v_target_value > 0 THEN
        v_achievement_pct := (v_actual_value / v_target_value) * 100;
    ELSE
        v_achievement_pct := 0;
    END IF;
    
    -- Определить статус
    v_status := get_achievement_status(v_achievement_pct, v_comparison_type);
    
    -- Определить тренд (упрощённо)
    v_trend := 'STABLE';  -- TODO: Реализовать расчёт тренда
    
    -- Рассчитать оценку
    v_score := LEAST(GREATEST(v_achievement_pct, 0), 100);
    
    -- Сохранить оценку
    INSERT INTO bizscore_assessment (
        template_id, object_type, object_id, period,
        actual_value, target_value, achievement_pct, status, trend, score
    ) VALUES (
        p_template_id, p_object_type, p_object_id, p_period,
        v_actual_value, v_target_value, v_achievement_pct, v_status, v_trend, v_score
    ) ON CONFLICT (template_id, object_type, object_id, period) 
      DO UPDATE SET
        actual_value = v_actual_value,
        target_value = v_target_value,
        achievement_pct = v_achievement_pct,
        status = v_status,
        trend = v_trend,
        score = v_score;
END;
$$;

-- Процедура: Рассчитать глобальный показатель
CREATE OR REPLACE PROCEDURE calculate_global_score(p_user_id INTEGER, p_period DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_score DECIMAL(5,2);
    v_components JSONB;
BEGIN
    -- Рассчитать взвешенную сумму
    SELECT 
        SUM(bsa.score * bst.weight),
        JSONB_AGG(JSONB_BUILD_OBJECT(
            'template_id', bsa.template_id,
            'score', bsa.score,
            'weight', bst.weight,
            'weighted_score', bsa.score * bst.weight
        ))
    INTO v_total_score, v_components
    FROM bizscore_assessment bsa
    JOIN bizscore_template bst ON bst.id = bsa.template_id
    WHERE bsa.object_id = p_user_id
      AND bsa.period = p_period;
    
    -- Обрезать до 100
    v_total_score := LEAST(v_total_score, 100);
    
    -- Сохранить
    INSERT INTO bizscore_global (user_id, period, total_score, components)
    VALUES (p_user_id, p_period, v_total_score, v_components)
    ON CONFLICT (user_id, period)
      DO UPDATE SET total_score = v_total_score, components = v_components;
END;
$$;

-- Представление: Текущие показатели с оценками
CREATE OR REPLACE VIEW v_bizscore_current AS
SELECT 
    bst.id AS template_id,
    bst.name AS template_name,
    bst.category,
    bst.target_value,
    bst.unit,
    bsv.value AS actual_value,
    CASE 
        WHEN bst.target_value > 0 THEN (bsv.value / bst.target_value) * 100 
        ELSE 0 
    END AS achievement_pct,
    get_achievement_status(
        CASE 
            WHEN bst.target_value > 0 THEN (bsv.value / bst.target_value) * 100 
            ELSE 0 
        END,
        bst.comparison_type
    ) AS status
FROM bizscore_template bst
LEFT JOIN LATERAL (
    SELECT value
    FROM bizscore_value
    WHERE template_id = bst.id
    ORDER BY period_end DESC
    LIMIT 1
) bsv ON true;

-- Представление: Рейтинг пользователей
CREATE OR REPLACE VIEW v_bizscore_ranking AS
SELECT 
    bsg.user_id,
    bsg.period,
    bsg.total_score,
    bsg.rank,
    ROW_NUMBER() OVER (PARTITION BY bsg.period ORDER BY bsg.total_score DESC) AS new_rank
FROM bizscore_global bsg;

-- Представление: Динамика показателей
CREATE OR REPLACE VIEW v_bizscore_trend AS
SELECT 
    bsv.template_id,
    bst.name AS template_name,
    bsv.period_start,
    bsv.period_end,
    bsv.value,
    LAG(bsv.value) OVER (
        PARTITION BY bsv.template_id, bsv.object_type, bsv.object_id 
        ORDER BY bsv.period_start
    ) AS prev_value,
    CASE 
        WHEN LAG(bsv.value) OVER (PARTITION BY bsv.template_id, bsv.object_type, bsv.object_id ORDER BY bsv.period_start) > 0
        THEN ((bsv.value - LAG(bsv.value) OVER (
            PARTITION BY bsv.template_id, bsv.object_type, bsv.object_id 
            ORDER BY bsv.period_start
        )) / LAG(bsv.value) OVER (
            PARTITION BY bsv.template_id, bsv.object_type, bsv.object_id 
            ORDER BY bsv.period_start
        )) * 100
        ELSE 0
    END AS change_pct
FROM bizscore_value bsv
JOIN bizscore_template bst ON bst.id = bsv.template_id
ORDER BY bsv.template_id, bsv.period_start;

-- Триггер: Обновить updated_at
CREATE OR REPLACE FUNCTION update_bizscore_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_bizscore_template_updated
    BEFORE UPDATE ON bizscore_template
    FOR EACH ROW
    EXECUTE FUNCTION update_bizscore_timestamp();
