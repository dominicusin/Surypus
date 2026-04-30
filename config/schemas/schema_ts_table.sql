-- =============================================================================
-- ТАБЛИЦЫ ВРЕМЕННЫХ СЕРИЙ
-- Соответствуют Core.Analytics.TSTable
-- Аналог: PPOBJ_TIMESERIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS ts_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INT DEFAULT 0,
    freq INT NOT NULL,  -- 1:Minutely, 2:Hourly, 3:Daily, 4:Weekly, 5:Monthly, 6:Quarterly, 7:Yearly
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO ts_table (id, name, freq) VALUES
(1, 'Продажи по дням', 3),
(2, 'Продажи по часам', 2),
(3, 'Остатки по дням', 3)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_ts_table_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ts_table_update
    BEFORE UPDATE ON ts_table
    FOR EACH ROW
    EXECUTE FUNCTION update_ts_table_timestamp();
