-- =============================================================================
-- СЕРИИ ПЕРСОНАЛЬНЫХ КАРТ
-- Соответствуют Core.Commerce.SCardSeries
-- Аналог: PPOBJ_SCARDSERIES
-- =============================================================================

-- =============================================================================
-- SCard Type (Тип карты)
-- =============================================================================
CREATE TABLE IF NOT EXISTS scard_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- SCard Series (Серия карт)
-- =============================================================================
CREATE TABLE IF NOT EXISTS scard_series (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    series VARCHAR(32) NOT NULL,
    person_kind_id INT DEFAULT 0,
    card_type_id INT REFERENCES scard_type(id),
    flags INT DEFAULT 0,  -- 1:Архивная
    start_number INT NOT NULL,
    end_number INT NOT NULL,
    issued_amount NUMERIC(18,4) DEFAULT 0,
    max_bonus NUMERIC(18,4) DEFAULT 0,
    discount NUMERIC(5,2) DEFAULT 0 CHECK (discount >= 0 AND discount <= 100),
    paym_term INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_scard_series_numbers CHECK (end_number >= start_number)
);

CREATE UNIQUE INDEX idx_scard_series_series ON scard_series(series);
CREATE INDEX idx_scard_series_person_kind ON scard_series(person_kind_id);
CREATE INDEX idx_scard_series_card_type ON scard_series(card_type_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION update_scard_series_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_scard_series_update
    BEFORE UPDATE ON scard_series
    FOR EACH ROW
    EXECUTE FUNCTION update_scard_series_timestamp();

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Проверить доступность номера карты
CREATE OR REPLACE FUNCTION check_card_number_available(p_series_id INT, p_card_number INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_available BOOLEAN;
BEGIN
    PERFORM id FROM scard_series 
    WHERE id = p_series_id 
      AND start_number <= p_card_number 
      AND end_number >= p_card_number;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Проверяем, не выдана ли уже карта с таким номером
    PERFORM id FROM scard 
    WHERE series_id = p_series_id AND number = p_card_number;
    
    RETURN NOT FOUND;
END;
$$ LANGUAGE plpgsql;

-- Получить следующий доступный номер карты
CREATE OR REPLACE FUNCTION get_next_card_number(p_series_id INT)
RETURNS INT AS $$
DECLARE
    v_next_number INT;
    v_max_used INT;
BEGIN
    -- Получаем максимальный выданный номер
    SELECT COALESCE(MAX(number), 0) INTO v_max_used
    FROM scard
    WHERE series_id = p_series_id;
    
    -- Получаем начальный номер серии
    SELECT start_number INTO v_next_number
    FROM scard_series
    WHERE id = p_series_id;
    
    -- Находим первый неиспользуемый номер
    WHILE v_next_number <= (SELECT end_number FROM scard_series WHERE id = p_series_id) LOOP
        PERFORM id FROM scard WHERE series_id = p_series_id AND number = v_next_number;
        IF NOT FOUND THEN
            RETURN v_next_number;
        END IF;
        v_next_number := v_next_number + 1;
    END LOOP;
    
    RETURN -1;  -- Нет доступных номеров
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Статистика по сериям карт
CREATE OR REPLACE VIEW v_scard_series_stats AS
SELECT 
    ss.id,
    ss.name,
    ss.series,
    ss.start_number,
    ss.end_number,
    ss.end_number - ss.start_number + 1 AS total_numbers,
    COUNT(sc.id) AS issued_cards,
    (ss.end_number - ss.start_number + 1) - COUNT(sc.id) AS available_numbers,
    COALESCE(SUM(sc.balance), 0) AS total_balance,
    COALESCE(SUM(sc.bonus), 0) AS total_bonus
FROM scard_series ss
LEFT JOIN scard sc ON sc.series_id = ss.id
GROUP BY ss.id, ss.name, ss.series, ss.start_number, ss.end_number;
