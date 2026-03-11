-- =============================================================================
-- ПЕРИОДИЧНОСТЬ
-- Соответствуют Core.Common.DateTimeRep
-- Аналог: PPOBJ_DATETIMEREP
-- =============================================================================

CREATE TABLE IF NOT EXISTS date_time_rep (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    kind INT NOT NULL,  -- 1:Day, 2:Week, 3:Month, 4:Quarter, 5:Year
    period INT NOT NULL CHECK (period > 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_date_time_rep_kind ON date_time_rep(kind);

-- DEFAULT DATA
INSERT INTO date_time_rep (id, name, kind, period) VALUES
(1, 'Ежедневно', 1, 1),
(2, 'Каждые 2 дня', 1, 2),
(3, 'Еженедельно', 2, 1),
(4, 'Раз в 2 недели', 2, 2),
(5, 'Ежемесячно', 3, 1),
(6, 'Раз в 2 месяца', 3, 2),
(7, 'Раз в 3 месяца', 4, 1),
(8, 'Раз в 6 месяцев', 4, 2),
(9, 'Ежегодно', 5, 1)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_date_time_rep_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_date_time_rep_update
    BEFORE UPDATE ON date_time_rep
    FOR EACH ROW
    EXECUTE FUNCTION update_date_time_rep_timestamp();

-- FUNCTION: Рассчитать следующую дату по периодичности
CREATE OR REPLACE FUNCTION calculate_next_date(p_kind INT, p_period INT, p_start_date DATE)
RETURNS DATE AS $$
DECLARE
    v_next_date DATE;
BEGIN
    CASE p_kind
        WHEN 1 THEN  -- Day
            v_next_date := p_start_date + (p_period || ' days')::INTERVAL;
        WHEN 2 THEN  -- Week
            v_next_date := p_start_date + (p_period * 7 || ' days')::INTERVAL;
        WHEN 3 THEN  -- Month
            v_next_date := p_start_date + (p_period || ' months')::INTERVAL;
        WHEN 4 THEN  -- Quarter
            v_next_date := p_start_date + (p_period * 3 || ' months')::INTERVAL;
        WHEN 5 THEN  -- Year
            v_next_date := p_start_date + (p_period || ' years')::INTERVAL;
        ELSE
            v_next_date := p_start_date;
    END CASE;
    
    RETURN v_next_date;
END;
$$ LANGUAGE plpgsql;
