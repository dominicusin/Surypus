-- ============================================================================
-- SCHEMA: TimeSeries (Временные ряды)
-- Соответствует C++ классам TimeSeriesCore в objtimeseries.cpp
-- ============================================================================

-- Таблица временных рядов
CREATE TABLE IF NOT EXISTS time_series (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    unit            VARCHAR(50),
    frequency       VARCHAR(20) NOT NULL,  -- MINUTE, HOUR, DAY, WEEK, MONTH, QUARTER, YEAR
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ts_name_not_empty CHECK (LENGTH(TRIM(name)) > 0)
);

-- Таблица точек временного ряда
CREATE TABLE IF NOT EXISTS time_series_point (
    id              SERIAL PRIMARY KEY,
    series_id       INTEGER NOT NULL REFERENCES time_series(id) ON DELETE CASCADE,
    timestamp       TIMESTAMP NOT NULL,
    value           DECIMAL(18,6) NOT NULL,
    flags           INTEGER DEFAULT 0,
    
    CONSTRAINT tsp_series_fk FOREIGN KEY (series_id) REFERENCES time_series(id),
    CONSTRAINT tsp_value_not_negative CHECK (value >= 0),
    CONSTRAINT tsp_unique_point UNIQUE (series_id, timestamp)
);

-- Индексы для оптимизации запросов
CREATE INDEX IF NOT EXISTS idx_tsp_series_timestamp ON time_series_point(series_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_tsp_timestamp ON time_series_point(timestamp);

-- Таблица анализов временных рядов
CREATE TABLE IF NOT EXISTS time_series_analysis (
    id              SERIAL PRIMARY KEY,
    series_id       INTEGER NOT NULL REFERENCES time_series(id) ON DELETE CASCADE,
    analysis_type   VARCHAR(20) NOT NULL,  -- TREND, SEASONAL, CYCLE, NOISE, ALL
    coeffs          JSONB,                  -- Коэффициенты модели
    r2              DECIMAL(5,4),           -- R-квадрат (0-1)
    rmse            DECIMAL(18,6),          -- Среднеквадратичная ошибка
    mape            DECIMAL(5,2),           -- Средняя абсолютная % ошибка
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT tsa_series_fk FOREIGN KEY (series_id) REFERENCES time_series(id),
    CONSTRAINT tsa_r2_range CHECK (r2 >= 0 AND r2 <= 1),
    CONSTRAINT tsa_rmse_positive CHECK (rmse >= 0),
    CONSTRAINT tsa_mape_positive CHECK (mape >= 0)
);

-- Таблица прогнозов
CREATE TABLE IF NOT EXISTS time_series_forecast (
    id              SERIAL PRIMARY KEY,
    series_id       INTEGER NOT NULL REFERENCES time_series(id) ON DELETE CASCADE,
    horizon         INTEGER NOT NULL,        -- Горизонт прогноза (периодов)
    values          JSONB NOT NULL,          -- Прогнозные значения
    confidence_low  DECIMAL(18,6),
    confidence_high DECIMAL(18,6),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT tsf_series_fk FOREIGN KEY (series_id) REFERENCES time_series(id),
    CONSTRAINT tsf_horizon_positive CHECK (horizon > 0)
);

-- Таблица моделей временных рядов
CREATE TABLE IF NOT EXISTS time_series_model (
    id              SERIAL PRIMARY KEY,
    series_id       INTEGER NOT NULL REFERENCES time_series(id) ON DELETE CASCADE,
    model_type      VARCHAR(50) NOT NULL,    -- ARIMA, EXPONENTIAL, LINEAR, etc.
    params          JSONB,                   -- Параметры модели
    fitted_values   JSONB,                   -- Сглаженные значения
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at      TIMESTAMP,               -- Срок действия модели
    
    CONSTRAINT tsm_series_fk FOREIGN KEY (series_id) REFERENCES time_series(id)
);

-- Функция: Получить временной ряд с агрегацией
CREATE OR REPLACE FUNCTION get_time_series_aggregated(
    p_series_id INTEGER,
    p_agg_type VARCHAR(10),  -- SUM, AVG, MIN, MAX, COUNT
    p_start_date TIMESTAMP,
    p_end_date TIMESTAMP
)
RETURNS TABLE (period_start TIMESTAMP, period_end TIMESTAMP, value DECIMAL(18,6)) AS $$
BEGIN
    RETURN QUERY
    WITH period_points AS (
        SELECT 
            date_trunc('day', timestamp) AS period,
            value
        FROM time_series_point
        WHERE series_id = p_series_id
          AND timestamp >= p_start_date
          AND timestamp <= p_end_date
    )
    SELECT 
        period AS period_start,
        period AS period_end,
        CASE p_agg_type
            WHEN 'SUM' THEN SUM(value)
            WHEN 'AVG' THEN AVG(value)
            WHEN 'MIN' THEN MIN(value)
            WHEN 'MAX' THEN MAX(value)
            WHEN 'COUNT' THEN COUNT(value)::DECIMAL
            ELSE AVG(value)
        END AS value
    FROM period_points
    GROUP BY period
    ORDER BY period;
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать скользящее среднее
CREATE OR REPLACE FUNCTION calculate_moving_average(
    p_series_id INTEGER,
    p_window_size INTEGER
)
RETURNS TABLE (timestamp TIMESTAMP, value DECIMAL(18,6), moving_avg DECIMAL(18,6)) AS $$
BEGIN
    RETURN QUERY
    WITH ordered_points AS (
        SELECT 
            timestamp,
            value,
            ROW_NUMBER() OVER (ORDER BY timestamp) AS rn,
            COUNT(*) OVER () AS total
        FROM time_series_point
        WHERE series_id = p_series_id
    )
    SELECT 
        o.timestamp,
        o.value,
        AVG(i.value) OVER (
            ORDER BY o.timestamp
            ROWS BETWEEN p_window_size - 1 PRECEDING AND CURRENT ROW
        ) AS moving_avg
    FROM ordered_points o
    JOIN time_series_point i ON i.series_id = p_series_id
    WHERE i.timestamp >= o.timestamp - (p_window_size || ' days')::INTERVAL
      AND i.timestamp <= o.timestamp
    GROUP BY o.timestamp, o.value;
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать тренд (линейная регрессия)
CREATE OR REPLACE FUNCTION calculate_time_series_trend(p_series_id INTEGER)
RETURNS TABLE (slope DECIMAL(18,8), intercept DECIMAL(18,8), r2 DECIMAL(5,4)) AS $$
DECLARE
    v_slope DECIMAL(18,8);
    v_intercept DECIMAL(18,8);
    v_r2 DECIMAL(5,4);
    v_n INTEGER;
    v_mean_x DECIMAL(18,8);
    v_mean_y DECIMAL(18,8);
    v_num DECIMAL(18,8);
    v_denom DECIMAL(18,8);
    v_ss_tot DECIMAL(18,8);
    v_ss_res DECIMAL(18,8);
BEGIN
    -- Подсчитать количество точек
    SELECT COUNT(*), AVG(EXTRACT(EPOCH FROM timestamp)), AVG(value)
    INTO v_n, v_mean_x, v_mean_y
    FROM time_series_point
    WHERE series_id = p_series_id;
    
    IF v_n < 2 THEN
        RETURN;
    END IF;
    
    -- Рассчитать коэффициенты линейной регрессии
    SELECT 
        SUM((EXTRACT(EPOCH FROM timestamp) - v_mean_x) * (value - v_mean_y)),
        SUMPOWER(EXTRACT(EPOCH FROM timestamp) - v_mean_x, 2)
    INTO v_num, v_denom
    FROM time_series_point
    WHERE series_id = p_series_id;
    
    v_slope := v_num / v_denom;
    v_intercept := v_mean_y - v_slope * v_mean_x;
    
    -- Рассчитать R-квадрат
    SELECT 
        SUMPOWER(value - v_intercept - v_slope * EXTRACT(EPOCH FROM timestamp), 2),
        SUMPOWER(value - v_mean_y, 2)
    INTO v_ss_res, v_ss_tot
    FROM time_series_point
    WHERE series_id = p_series_id;
    
    v_r2 := 1 - (v_ss_res / v_ss_tot);
    
    RETURN QUERY SELECT v_slope, v_intercept, v_r2;
END;
$$ LANGUAGE plpgsql;

-- Триггер: Обновить updated_at при изменении
CREATE OR REPLACE FUNCTION update_time_series_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_time_series_updated
    BEFORE UPDATE ON time_series
    FOR EACH ROW
    EXECUTE FUNCTION update_time_series_timestamp();

-- Представление: Последние значения временного ряда
CREATE OR REPLACE VIEW v_time_series_latest AS
SELECT 
    ts.id,
    ts.name,
    ts.frequency,
    tsp.timestamp AS last_timestamp,
    tsp.value AS last_value,
    COUNT(tspn.id) OVER (PARTITION BY ts.id) AS point_count
FROM time_series ts
JOIN LATERAL (
    SELECT timestamp, value
    FROM time_series_point
    WHERE series_id = ts.id
    ORDER BY timestamp DESC
    LIMIT 1
) tsp ON true
LEFT JOIN time_series_point tspn ON tspn.series_id = ts.id;

-- Представление: Статистика временного ряда
CREATE OR REPLACE VIEW v_time_series_stats AS
SELECT 
    series_id,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    AVG(value) AS avg_value,
    STDDEV(value) AS stddev,
    COUNT(*) AS point_count,
    MIN(timestamp) AS first_point,
    MAX(timestamp) AS last_point
FROM time_series_point
GROUP BY series_id;
