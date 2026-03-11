-- =============================================================================
-- ПЕРСОНАЛЬНАЯ РЕГИСТРАЦИЯ (CHECK-IN)
-- Соответствуют Core.Production.CheckIn
-- Аналог: OpenPapyrus pplib/chkinpsn.cpp (PPOBJ_CHKINP)
-- =============================================================================

-- =============================================================================
-- Check-In Configuration (Конфигурация)
-- =============================================================================
CREATE TABLE IF NOT EXISTS check_in_config (
    id SERIAL PRIMARY KEY,
    session_id INT NOT NULL,
    flags INT DEFAULT 0,
    person_kind_id INT DEFAULT 0,
    location_id INT DEFAULT 0,
    capacity INT DEFAULT 0,
    goods_id INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_check_in_config_session ON check_in_config(session_id);

-- =============================================================================
-- Check-In Item (Элемент регистрации)
-- =============================================================================
CREATE TABLE IF NOT EXISTS check_in_item (
    id SERIAL PRIMARY KEY,
    kind INT NOT NULL DEFAULT 0,  -- 0:TSession, 1:Attendance, 2:Job
    flags INT DEFAULT 0,
    status INT NOT NULL DEFAULT 0,  -- 0:Registered, 1:CheckedIn, 2:Canceled
    person_id INT NOT NULL,
    prmr_id INT NOT NULL,  -- Primary member ID
    place_code VARCHAR(32),
    reg_dt DATE NOT NULL,
    reg_tm TIME NOT NULL,
    ci_dt DATE,
    ci_tm TIME,
    amount NUMERIC(18,4) DEFAULT 0,
    goods_id INT DEFAULT 0,
    session_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Индексы
CREATE INDEX idx_check_in_item_session ON check_in_item(session_id);
CREATE INDEX idx_check_in_item_person ON check_in_item(person_id);
CREATE INDEX idx_check_in_item_status ON check_in_item(status);
CREATE INDEX idx_check_in_item_reg_dt ON check_in_item(reg_dt);
CREATE INDEX idx_check_in_item_prmr ON check_in_item(prmr_id);
CREATE INDEX idx_check_in_item_session_status ON check_in_item(session_id, status);

-- =============================================================================
-- Check-In Totals (Итоги)
-- =============================================================================
CREATE TABLE IF NOT EXISTS check_in_total (
    id SERIAL PRIMARY KEY,
    session_id INT NOT NULL,
    reg_count INT DEFAULT 0,
    ci_count INT DEFAULT 0,
    canceled_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_check_in_total_session ON check_in_total(session_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION update_check_in_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_in_config_update
    BEFORE UPDATE ON check_in_config
    FOR EACH ROW
    EXECUTE FUNCTION update_check_in_timestamp();

CREATE TRIGGER trigger_check_in_item_update
    BEFORE UPDATE ON check_in_item
    FOR EACH ROW
    EXECUTE FUNCTION update_check_in_timestamp();

CREATE TRIGGER trigger_check_in_total_update
    BEFORE UPDATE ON check_in_total
    FOR EACH ROW
    EXECUTE FUNCTION update_check_in_timestamp();

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Регистрация персоны
CREATE OR REPLACE FUNCTION register_person(
    p_session_id INT,
    p_person_id INT,
    p_prmr_id INT,
    p_place_code VARCHAR,
    p_amount NUMERIC DEFAULT 0
)
RETURNS INT AS $$
DECLARE
    v_item_id INT;
    v_now TIMESTAMP := NOW();
BEGIN
    INSERT INTO check_in_item (
        kind, flags, status, person_id, prmr_id, place_code,
        reg_dt, reg_tm, amount, session_id
    ) VALUES (
        0, 0, 0, p_person_id, p_prmr_id, p_place_code,
        v_now::DATE, v_now::TIME, p_amount, p_session_id
    )
    RETURNING id INTO v_item_id;
    
    -- Обновляем итоги
    PERFORM update_check_in_totals(p_session_id);
    
    RETURN v_item_id;
END;
$$ LANGUAGE plpgsql;

-- Отметка (check-in)
CREATE OR REPLACE FUNCTION check_in_person(p_item_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_now TIMESTAMP := NOW();
BEGIN
    UPDATE check_in_item
    SET status = 1,  -- CheckedIn
        ci_dt = v_now::DATE,
        ci_tm = v_now::TIME,
        updated_at = v_now
    WHERE id = p_item_id AND status = 0;  -- Только зарегистрированные
    
    IF FOUND THEN
        PERFORM update_check_in_totals((SELECT session_id FROM check_in_item WHERE id = p_item_id));
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Отмена регистрации
CREATE OR REPLACE FUNCTION cancel_check_in(p_item_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_now TIMESTAMP := NOW();
    v_session_id INT;
BEGIN
    SELECT session_id INTO v_session_id
    FROM check_in_item
    WHERE id = p_item_id;
    
    UPDATE check_in_item
    SET status = 2,  -- Canceled
        updated_at = v_now
    WHERE id = p_item_id AND status != 2;
    
    IF FOUND THEN
        PERFORM update_check_in_totals(v_session_id);
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Обновление итогов
CREATE OR REPLACE FUNCTION update_check_in_totals(p_session_id INT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO check_in_total (session_id, reg_count, ci_count, canceled_count)
    SELECT 
        p_session_id,
        COUNT(*) as reg_count,
        SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as ci_count,
        SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as canceled_count
    FROM check_in_item
    WHERE session_id = p_session_id
    ON CONFLICT (session_id) DO UPDATE
    SET reg_count = EXCLUDED.reg_count,
        ci_count = EXCLUDED.ci_count,
        canceled_count = EXCLUDED.canceled_count,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Получить итоги по сессии
CREATE OR REPLACE FUNCTION get_check_in_totals(p_session_id INT)
RETURNS TABLE (
    reg_count INT,
    ci_count INT,
    canceled_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(t.reg_count, 0),
        COALESCE(t.ci_count, 0),
        COALESCE(t.canceled_count, 0)
    FROM check_in_total t
    WHERE t.session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- CONSTRAINTS
-- =============================================================================

ALTER TABLE check_in_item
ADD CONSTRAINT chk_check_in_amount CHECK (amount >= 0);

ALTER TABLE check_in_item
ADD CONSTRAINT chk_check_in_status CHECK (status IN (0, 1, 2));

ALTER TABLE check_in_item
ADD CONSTRAINT chk_check_in_kind CHECK (kind IN (0, 1, 2));
