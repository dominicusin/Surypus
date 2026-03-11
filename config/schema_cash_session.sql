-- =============================================================================
-- КАССОВЫЕ СЕССИИ (CASH SESSION)
-- Соответствуют Core.CashSession
-- Аналог: pplib/csess.cpp (PPOBJ_CSESSION)
-- =============================================================================

-- =============================================================================
-- Cash Session (Кассовая сессия)
-- =============================================================================
CREATE TABLE IF NOT EXISTS cash_session (
    id BIGSERIAL PRIMARY KEY,
    cash_node_id INT NOT NULL,
    cash_number INT NOT NULL DEFAULT 0,
    sess_number INT NOT NULL DEFAULT 0,
    dt DATE NOT NULL,
    tm TIME NOT NULL,
    end_dt DATE,
    end_tm TIME,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    cash NUMERIC(18,4) NOT NULL DEFAULT 0,
    card NUMERIC(18,4) NOT NULL DEFAULT 0,
    flags INT DEFAULT 0,
    incomplete INT NOT NULL DEFAULT 0,
    temporary BOOLEAN DEFAULT FALSE,
    super_sess_id INT DEFAULT 0,
    user_id INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX idx_cash_session_cash_node ON cash_session(cash_node_id);
CREATE INDEX idx_cash_session_date ON cash_session(dt);
CREATE INDEX idx_cash_session_cash_node_date ON cash_session(cash_node_id, dt DESC);
CREATE INDEX idx_cash_session_super ON cash_session(super_sess_id);
CREATE INDEX idx_cash_session_incomplete ON cash_session(incomplete) WHERE incomplete > 0;
CREATE INDEX idx_cash_session_temp ON cash_session(temporary) WHERE temporary = TRUE;

-- =============================================================================
-- Cash Session Check (Чек кассовой сессии)
-- =============================================================================
CREATE TABLE IF NOT EXISTS cash_session_check (
    id BIGSERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
    check_number INT NOT NULL,
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    cash NUMERIC(18,4) NOT NULL DEFAULT 0,
    card NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    return_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cash_session_check_session ON cash_session_check(session_id);
CREATE INDEX idx_cash_session_check_number ON cash_session_check(session_id, check_number);

-- =============================================================================
-- Cash Session Cashier (Кассиры сессии)
-- =============================================================================
CREATE TABLE IF NOT EXISTS cash_session_cashier (
    id BIGSERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
    user_id INT NOT NULL,
    role INT NOT NULL DEFAULT 0,  -- 0:Кассир, 1:Администратор
    login_dt TIMESTAMPTZ NOT NULL,
    logout_dt TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cash_session_cashier_session ON cash_session_cashier(session_id);
CREATE INDEX idx_cash_session_cashier_user ON cash_session_cashier(user_id);

-- =============================================================================
-- Cash Session Total (Итоги сессии по видам оплаты)
-- =============================================================================
CREATE TABLE IF NOT EXISTS cash_session_total (
    id BIGSERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
    payment_type INT NOT NULL,  -- 0:Наличные, 1:Карта, 2:Безнал, 3:QR и т.д.
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cash_session_total_session ON cash_session_total(session_id);
CREATE UNIQUE INDEX idx_cash_session_total_session_type ON cash_session_total(session_id, payment_type);

-- =============================================================================
-- Cash Session Event (События сессии)
-- =============================================================================
CREATE TABLE IF NOT EXISTS cash_session_event (
    id BIGSERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
    event_type INT NOT NULL,  -- 0:Открытие, 1:Закрытие, 2:Внесение, 3:Изъятие
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    amount NUMERIC(18,4) DEFAULT 0,
    user_id INT DEFAULT 0,
    descr TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cash_session_event_session ON cash_session_event(session_id);
CREATE INDEX idx_cash_session_event_dt ON cash_session_event(dt);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Обновление updated_at при изменении записи
CREATE OR REPLACE FUNCTION update_cash_session_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cash_session_update
    BEFORE UPDATE ON cash_session
    FOR EACH ROW
    EXECUTE FUNCTION update_cash_session_timestamp();

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Получить последний номер сессии для кассового узла
CREATE OR REPLACE FUNCTION get_last_session_number(p_cash_node_id INT, p_cash_number INT)
RETURNS INT AS $$
DECLARE
    v_last_number INT;
BEGIN
    SELECT COALESCE(MAX(sess_number), 0) INTO v_last_number
    FROM cash_session
    WHERE cash_node_id = p_cash_node_id AND cash_number = p_cash_number;
    
    RETURN v_last_number;
END;
$$ LANGUAGE plpgsql;

-- Создать новую кассовую сессию
CREATE OR REPLACE FUNCTION create_cash_session(
    p_cash_node_id INT,
    p_cash_number INT,
    p_user_id INT DEFAULT 0
)
RETURNS INT AS $$
DECLARE
    v_session_id INT;
    v_sess_number INT;
BEGIN
    -- Получаем номер сессии
    v_sess_number := get_last_session_number(p_cash_node_id, p_cash_number) + 1;
    
    -- Создаём сессию
    INSERT INTO cash_session (
        cash_node_id, cash_number, sess_number, 
        dt, tm, total, cash, card, 
        flags, incomplete, temporary, user_id
    ) VALUES (
        p_cash_node_id, p_cash_number, v_sess_number,
        CURRENT_DATE, CURRENT_TIME, 0, 0, 0,
        0, 0, FALSE, p_user_id
    )
    RETURNING id INTO v_session_id;
    
    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

-- Закрыть кассовую сессию
CREATE OR REPLACE FUNCTION close_cash_session(
    p_session_id INT,
    p_total NUMERIC,
    p_cash NUMERIC,
    p_card NUMERIC
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE cash_session
    SET end_dt = CURRENT_DATE,
        end_tm = CURRENT_TIME,
        total = p_total,
        cash = p_cash,
        card = p_card,
        flags = flags | 2,  -- CSF_CLOSED
        incomplete = 0,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_session_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Получить итоги сессии
CREATE OR REPLACE FUNCTION get_session_totals(p_session_id INT)
RETURNS TABLE (
    total_amount NUMERIC(18,4),
    cash_amount NUMERIC(18,4),
    card_amount NUMERIC(18,4),
    check_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(cs.total, 0),
        COALESCE(cs.cash, 0),
        COALESCE(cs.card, 0),
        (SELECT COUNT(*) FROM cash_session_check WHERE session_id = p_session_id)
    FROM cash_session cs
    WHERE cs.id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Активные сессии
CREATE OR REPLACE VIEW v_active_sessions AS
SELECT 
    cs.id,
    cs.cash_node_id,
    cs.cash_number,
    cs.sess_number,
    cs.dt,
    cs.tm,
    cs.total,
    cs.cash,
    cs.card,
    cs.flags,
    cs.incomplete,
    cs.user_id,
    cn.name AS cash_node_name,
    cn.symb AS cash_node_symb
FROM cash_session cs
LEFT JOIN cash_node cn ON cn.id = cs.cash_node_id
WHERE cs.end_dt IS NULL AND cs.temporary = FALSE
ORDER BY cs.cash_node_id, cs.dt DESC, cs.tm DESC;

-- Сессии за сегодня
CREATE OR REPLACE VIEW v_today_sessions AS
SELECT 
    cs.id,
    cs.cash_node_id,
    cs.cash_number,
    cs.sess_number,
    cs.dt,
    cs.tm,
    cs.end_dt,
    cs.end_tm,
    cs.total,
    cs.cash,
    cs.card,
    cs.flags,
    cs.incomplete,
    cn.name AS cash_node_name
FROM cash_session cs
LEFT JOIN cash_node cn ON cn.id = cs.cash_node_id
WHERE cs.dt = CURRENT_DATE
ORDER BY cs.cash_node_id, cs.tm;

-- =============================================================================
-- CONSTRAINTS
-- =============================================================================

-- Проверка сумм
ALTER TABLE cash_session 
ADD CONSTRAINT chk_cash_session_total CHECK (total >= 0);
ALTER TABLE cash_session 
ADD CONSTRAINT chk_cash_session_cash CHECK (cash >= 0);
ALTER TABLE cash_session 
ADD CONSTRAINT chk_cash_session_card CHECK (card >= 0);
ALTER TABLE cash_session 
ADD CONSTRAINT chk_cash_session_incomplete CHECK (incomplete >= 0);
