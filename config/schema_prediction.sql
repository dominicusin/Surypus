-- ============================================================================
-- SCHEMA: Prediction (Прогнозирование продаж)
-- Соответствует C++ классам PredictSalesCore в psales.cpp
-- ============================================================================

-- Таблица параметров прогноза
CREATE TABLE IF NOT EXISTS predict_param (
    id              SERIAL PRIMARY KEY,
    goods_id        INTEGER NOT NULL,
    location_id     INTEGER NOT NULL,
    start_date      DATE NOT NULL,
    horizon         INTEGER NOT NULL DEFAULT 30,
    method          VARCHAR(50) NOT NULL DEFAULT 'EXPONENTIAL',
    alpha           DECIMAL(5,4) DEFAULT 0.3,  -- Параметр сглаживания
    beta            DECIMAL(5,4) DEFAULT 0.1,   -- Параметр тренда
    season_period   INTEGER DEFAULT 7,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT pp_horizon_check CHECK (horizon > 0 AND horizon <= 365),
    CONSTRAINT pp_alpha_check CHECK (alpha > 0 AND alpha < 1),
    CONSTRAINT pp_beta_check CHECK (beta > 0 AND beta < 1),
    CONSTRAINT pp_season_check CHECK (season_period > 0)
);

-- Таблица результатов прогноза
CREATE TABLE IF NOT EXISTS predict_result (
    id              SERIAL PRIMARY KEY,
    param_id        INTEGER NOT NULL REFERENCES predict_param(id) ON DELETE CASCADE,
    goods_id        INTEGER NOT NULL,
    location_id     INTEGER NOT NULL,
    period          DATE NOT NULL,
    forecast        DECIMAL(18,6) NOT NULL,
    lower_bound     DECIMAL(18,6),
    upper_bound     DECIMAL(18,6),
    confidence      DECIMAL(5,4) DEFAULT 0.95,
    method          VARCHAR(50),
    error           DECIMAL(18,6),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT pr_param_fk FOREIGN KEY (param_id) REFERENCES predict_param(id),
    CONSTRAINT pr_forecast_nonnegative CHECK (forecast >= 0),
    CONSTRAINT pr_bounds_check CHECK (lower_bound <= forecast AND forecast <= upper_bound),
    CONSTRAINT pr_confidence_check CHECK (confidence > 0 AND confidence <= 1)
);

-- Таблица статистики прогноза
CREATE TABLE IF NOT EXISTS predict_stat (
    id              SERIAL PRIMARY KEY,
    goods_id        INTEGER NOT NULL,
    location_id     INTEGER NOT NULL,
    avg_demand      DECIMAL(18,6) NOT NULL,
    std_dev         DECIMAL(18,6) NOT NULL,
    trend           DECIMAL(18,8),
    seasonality     JSONB,
    last_update     DATE NOT NULL,
    accuracy        DECIMAL(5,4),  -- MAPE (0-1)
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ps_goods_location_unique UNIQUE (goods_id, location_id),
    CONSTRAINT ps_accuracy_check CHECK (accuracy >= 0 AND accuracy <= 1),
    CONSTRAINT ps_avg_demand_check CHECK (avg_demand >= 0),
    CONSTRAINT ps_std_dev_check CHECK (std_dev >= 0)
);

-- Таблица истории продаж для анализа
CREATE TABLE IF NOT EXISTS sales_history (
    id              SERIAL PRIMARY KEY,
    goods_id        INTEGER NOT NULL,
    location_id     INTEGER NOT NULL,
    period          DATE NOT NULL,
    quantity        DECIMAL(18,6) NOT NULL,
    revenue         DECIMAL(18,6),
    cost            DECIMAL(18,6),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT sh_goods_location_period_unique UNIQUE (goods_id, location_id, period),
    CONSTRAINT sh_quantity_check CHECK (quantity >= 0),
    CONSTRAINT sh_revenue_check CHECK (revenue IS NULL OR revenue >= 0),
    CONSTRAINT sh_cost_check CHECK (cost IS NULL OR cost >= 0)
);

-- Таблица точности прогнозов (для обучения)
CREATE TABLE IF NOT EXISTS predict_accuracy_log (
    id              SERIAL PRIMARY KEY,
    param_id        INTEGER REFERENCES predict_param(id) ON DELETE SET NULL,
    goods_id        INTEGER NOT NULL,
    location_id     INTEGER NOT NULL,
    period          DATE NOT NULL,
    actual_value    DECIMAL(18,6) NOT NULL,
    forecast_value  DECIMAL(18,6) NOT NULL,
    error           DECIMAL(18,6),
    abs_pct_error   DECIMAL(7,4),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT pal_accuracy_check CHECK (abs_pct_error >= 0)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_sh_goods_location ON sales_history(goods_id, location_id, period);
CREATE INDEX IF NOT EXISTS idx_sh_period ON sales_history(period DESC);
CREATE INDEX IF NOT EXISTS idx_pr_param_period ON predict_result(param_id, period);
CREATE INDEX IF NOT EXISTS idx_ps_goods_location ON predict_stat(goods_id, location_id);
CREATE INDEX IF NOT EXISTS idx_pal_period ON predict_accuracy_log(period DESC);

-- Функция: Рассчитать скользящее среднее
CREATE OR REPLACE FUNCTION calculate_moving_average(
    p_goods_id INTEGER,
    p_location_id INTEGER,
    p_window INTEGER,
    p_end_date DATE
)
RETURNS DECIMAL(18,6) AS $$
DECLARE
    v_result DECIMAL(18,6);
BEGIN
    SELECT AVG(quantity) INTO v_result
    FROM (
        SELECT quantity
        FROM sales_history
        WHERE goods_id = p_goods_id
          AND location_id = p_location_id
          AND period <= p_end_date
        ORDER BY period DESC
        LIMIT p_window
    ) sub;
    
    RETURN COALESCE(v_result, 0);
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать экспоненциальное сглаживание
CREATE OR REPLACE FUNCTION calculate_exponential_smoothing(
    p_goods_id INTEGER,
    p_location_id INTEGER,
    p_alpha DECIMAL,
    p_periods INTEGER
)
RETURNS TABLE (period DATE, level DECIMAL(18,6), trend DECIMAL(18,6)) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE smoothed AS (
        -- База: первое значение
        SELECT 
            period,
            quantity AS level,
            0::DECIMAL(18,6) AS trend,
            ROW_NUMBER() OVER (ORDER BY period) AS rn
        FROM sales_history
        WHERE goods_id = p_goods_id
          AND location_id = p_location_id
        ORDER BY period
        LIMIT 1
        
        UNION ALL
        
        -- Рекурсия: рассчитать следующие значения
        SELECT 
            s.period,
            p_alpha * s.quantity + (1 - p_alpha) * (smoothed.level + smoothed.trend) AS level,
            p_alpha * (smoothed.level + smoothed.trend - LAG(smoothed.level) OVER ()) + 
                (1 - p_alpha) * smoothed.trend AS trend,
            smoothed.rn + 1
        FROM sales_history s
        JOIN smoothed ON s.period > smoothed.period
        WHERE s.goods_id = p_goods_id
          AND s.location_id = p_location_id
        ORDER BY s.period
        LIMIT p_periods
    )
    SELECT period, level, trend FROM smoothed;
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать статистику продаж
CREATE OR REPLACE FUNCTION calculate_sales_stat(
    p_goods_id INTEGER,
    p_location_id INTEGER,
    p_days INTEGER DEFAULT 90
)
RETURNS TABLE (
    avg_demand DECIMAL(18,6),
    std_dev DECIMAL(18,6),
    trend DECIMAL(18,8)
) AS $$
DECLARE
    v_avg DECIMAL(18,6);
    v_std DECIMAL(18,6);
    v_trend DECIMAL(18,8);
    v_n INTEGER;
BEGIN
    -- Среднее значение
    SELECT AVG(quantity), COUNT(*), STDDEV(quantity)
    INTO v_avg, v_n, v_std
    FROM sales_history
    WHERE goods_id = p_goods_id
      AND location_id = p_location_id
      AND period >= CURRENT_DATE - (p_days || ' days')::INTERVAL;
    
    -- Тренд (линейная регрессия)
    SELECT 
        COALESCE(
            SUM((EXTRACT(EPOCH FROM period) - EXTRACT(EPOCH FROM AVG(period))) * 
                (quantity - v_avg)) / 
            NULLIF(SUM(POWER(EXTRACT(EPOCH FROM period) - EXTRACT(EPOCH FROM AVG(period)), 2)), 0),
            0
        )
    INTO v_trend
    FROM sales_history
    WHERE goods_id = p_goods_id
      AND location_id = p_location_id
      AND period >= CURRENT_DATE - (p_days || ' days')::INTERVAL;
    
    RETURN QUERY SELECT v_avg, v_std, v_trend;
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать MAPE (средняя абсолютная процентная ошибка)
CREATE OR REPLACE FUNCTION calculate_mape(
    p_goods_id INTEGER,
    p_location_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS DECIMAL(7,4) AS $$
DECLARE
    v_mape DECIMAL(7,4);
BEGIN
    SELECT AVG(ABS((actual.forecast_value - actual.actual_value) / NULLIF(actual.actual_value, 0)))
    INTO v_mape
    FROM predict_accuracy_log actual
    WHERE actual.goods_id = p_goods_id
      AND actual.location_id = p_location_id
      AND actual.period BETWEEN p_start_date AND p_end_date;
    
    RETURN COALESCE(v_mape, 0);
END;
$$ LANGUAGE plpgsql;

-- Процедура: Сделать прогноз
CREATE OR REPLACE PROCEDURE make_forecast(
    p_goods_id INTEGER,
    p_location_id INTEGER,
    p_method VARCHAR,
    p_horizon INTEGER,
    p_alpha DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_param_id INTEGER;
    v_forecast DECIMAL(18,6);
    v_std_dev DECIMAL(18,6);
    v_trend DECIMAL(18,8);
    v_period DATE;
    v_lower DECIMAL(18,6);
    v_upper DECIMAL(18,6);
    i INTEGER;
BEGIN
    -- Создать параметры прогноза
    INSERT INTO predict_param (goods_id, location_id, start_date, horizon, method, alpha)
    VALUES (p_goods_id, p_location_id, CURRENT_DATE, p_horizon, p_method, p_alpha)
    RETURNING id INTO v_param_id;
    
    -- Получить статистику
    SELECT avg_demand, std_dev, trend
    INTO v_forecast, v_std_dev, v_trend
    FROM calculate_sales_stat(p_goods_id, p_location_id, 90);
    
    -- Рассчитать доверительный интервал (95%)
    v_lower := v_forecast - 1.96 * v_std_dev;
    v_upper := v_forecast + 1.96 * v_std_dev;
    
    -- Создать прогноз для каждого периода
    FOR i IN 1..p_horizon LOOP
        v_period := CURRENT_DATE + (i || ' days')::INTERVAL;
        
        -- Применить тренд
        v_forecast := v_forecast + v_trend;
        
        INSERT INTO predict_result (
            param_id, goods_id, location_id, period, forecast,
            lower_bound, upper_bound, confidence, method, error
        ) VALUES (
            v_param_id, p_goods_id, p_location_id, v_period,
            GREATEST(v_forecast, 0),
            GREATEST(v_lower, 0), v_upper, 0.95, p_method, v_std_dev
        );
    END LOOP;
    
    -- Обновить/создать статистику
    INSERT INTO predict_stat (goods_id, location_id, avg_demand, std_dev, trend, last_update)
    VALUES (p_goods_id, p_location_id, v_forecast, v_std_dev, v_trend, CURRENT_DATE)
    ON CONFLICT (goods_id, location_id) 
      DO UPDATE SET avg_demand = v_forecast, std_dev = v_std_dev, trend = v_trend, last_update = CURRENT_DATE;
END;
$$;

-- Процедура: Логировать точность прогноза
CREATE OR REPLACE PROCEDURE log_forecast_accuracy(
    p_goods_id INTEGER,
    p_location_id INTEGER,
    p_period DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_actual DECIMAL(18,6);
    v_forecast DECIMAL(18,6);
    v_error DECIMAL(18,6);
    v_abs_pct_error DECIMAL(7,4);
BEGIN
    -- Получить фактическое значение
    SELECT quantity INTO v_actual
    FROM sales_history
    WHERE goods_id = p_goods_id
      AND location_id = p_location_id
      AND period = p_period;
    
    -- Получить прогнозное значение
    SELECT forecast INTO v_forecast
    FROM predict_result pr
    JOIN predict_param pp ON pp.id = pr.param_id
    WHERE pr.goods_id = p_goods_id
      AND pr.location_id = p_location_id
      AND pr.period = p_period
    ORDER BY pr.created_at DESC
    LIMIT 1;
    
    IF v_actual IS NOT NULL AND v_forecast IS NOT NULL THEN
        v_error := v_forecast - v_actual;
        v_abs_pct_error := ABS(v_error / NULLIF(v_actual, 0)) * 100;
        
        INSERT INTO predict_accuracy_log (
            goods_id, location_id, period,
            actual_value, forecast_value, error, abs_pct_error
        ) VALUES (
            p_goods_id, p_location_id, p_period,
            v_actual, v_forecast, v_error, v_abs_pct_error
        );
    END IF;
END;
$$;

-- Представление: Текущие прогнозы
CREATE OR REPLACE VIEW v_current_forecasts AS
SELECT 
    pr.goods_id,
    pr.location_id,
    pr.period,
    pr.forecast,
    pr.lower_bound,
    pr.upper_bound,
    pr.confidence,
    pp.method,
    pr.error
FROM predict_result pr
JOIN predict_param pp ON pp.id = pr.param_id
JOIN (
    SELECT goods_id, location_id, MAX(created_at) AS max_created
    FROM predict_result
    GROUP BY goods_id, location_id
) latest ON latest.goods_id = pr.goods_id 
         AND latest.location_id = pr.location_id
         AND latest.max_created = pr.created_at;

-- Представление: Точность прогнозов по товарам
CREATE OR REPLACE VIEW v_forecast_accuracy_by_goods AS
SELECT 
    goods_id,
    location_id,
    COUNT(*) AS forecast_count,
    AVG(abs_pct_error) AS avg_mape,
    MIN(abs_pct_error) AS min_mape,
    MAX(abs_pct_error) AS max_mape
FROM predict_accuracy_log
GROUP BY goods_id, location_id;

-- Представление: Тренды продаж
CREATE OR REPLACE VIEW v_sales_trends AS
WITH daily_sales AS (
    SELECT 
        goods_id, location_id, period, quantity,
        LAG(quantity) OVER (PARTITION BY goods_id, location_id ORDER BY period) AS prev_qty
    FROM sales_history
)
SELECT 
    goods_id, location_id, period, quantity,
    prev_qty,
    CASE 
        WHEN prev_qty > 0 THEN ((quantity - prev_qty) / prev_qty) * 100
        ELSE 0
    END AS change_pct
FROM daily_sales
ORDER BY goods_id, location_id, period;
