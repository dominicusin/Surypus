-- =============================================================================
-- ПЕРСОНАЛЬНЫЕ КАРТЫ
-- Соответствуют Core.Commerce.SCard
-- Аналог: PPOBJ_SCARD
-- =============================================================================

CREATE TABLE IF NOT EXISTS scard (
    id SERIAL PRIMARY KEY,
    series_id INT NOT NULL,
    number INT NOT NULL,
    person_id INT DEFAULT 0,
    owner_id INT DEFAULT 0,
    balance NUMERIC(18,4) DEFAULT 0 CHECK (balance >= 0),
    bonus NUMERIC(18,4) DEFAULT 0 CHECK (bonus >= 0),
    discount NUMERIC(5,2) DEFAULT 0 CHECK (discount >= 0 AND discount <= 100),
    flags INT DEFAULT 0,
    issued_date DATE NOT NULL,
    expiry_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(series_id, number)
);

CREATE INDEX idx_scard_series ON scard(series_id);
CREATE INDEX idx_scard_person ON scard(person_id);
CREATE INDEX idx_scard_owner ON scard(owner_id);
CREATE INDEX idx_scard_expiry ON scard(expiry_date);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_scard_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_scard_update
    BEFORE UPDATE ON scard
    FOR EACH ROW
    EXECUTE FUNCTION update_scard_timestamp();

-- FUNCTION: Начислить бонусы
CREATE OR REPLACE FUNCTION add_card_bonus(p_card_id INT, p_bonus NUMERIC(18,4))
RETURNS VOID AS $$
BEGIN
    IF p_bonus <= 0 THEN
        RAISE EXCEPTION 'Bonus must be positive';
    END IF;
    
    UPDATE scard 
    SET bonus = bonus + p_bonus,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_card_id;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Списать бонусы
CREATE OR REPLACE FUNCTION use_card_bonus(p_card_id INT, p_bonus NUMERIC(18,4))
RETURNS BOOLEAN AS $$
DECLARE
    v_current_bonus NUMERIC(18,4);
BEGIN
    IF p_bonus <= 0 THEN
        RETURN FALSE;
    END IF;
    
    SELECT bonus INTO v_current_bonus FROM scard WHERE id = p_card_id;
    
    IF v_current_bonus < p_bonus THEN
        RETURN FALSE;
    END IF;
    
    UPDATE scard 
    SET bonus = bonus - p_bonus,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_card_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- VIEW: Активные карты
CREATE OR REPLACE VIEW v_active_scards AS
SELECT 
    sc.id,
    sc.series_id,
    ss.name AS series_name,
    sc.number,
    sc.person_id,
    p.name AS person_name,
    sc.balance,
    sc.bonus,
    sc.discount,
    sc.expiry_date,
    CASE 
        WHEN sc.expiry_date IS NULL THEN 'Unlimited'
        WHEN sc.expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM scard sc
LEFT JOIN scard_series ss ON ss.id = sc.series_id
LEFT JOIN person p ON p.id = sc.person_id
WHERE sc.flags & 1 = 0  -- Не заблокирована
ORDER BY sc.number;
