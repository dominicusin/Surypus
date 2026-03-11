-- =============================================================================
-- РЕГИСТРАЦИОННЫЕ ДОКУМЕНТЫ
-- Соответствуют Core.Document.Register
-- Аналог: PPOBJ_REGISTER
-- =============================================================================

CREATE TABLE IF NOT EXISTS document_register (
    id SERIAL PRIMARY KEY,
    person_id INT NOT NULL,
    type_id INT NOT NULL,
    series VARCHAR(32),
    number VARCHAR(64) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE,
    issuer VARCHAR(512),
    flags INT DEFAULT 0,
    auto_number BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_document_register_person ON document_register(person_id);
CREATE INDEX idx_document_register_type ON document_register(type_id);
CREATE INDEX idx_document_register_expiry ON document_register(expiry_date);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_document_register_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_document_register_update
    BEFORE UPDATE ON document_register
    FOR EACH ROW
    EXECUTE FUNCTION update_document_register_timestamp();

-- VIEW: Действующие регистрации
CREATE OR REPLACE VIEW v_core_document_active_registers AS
SELECT 
    d.id,
    d.person_id,
    p.name AS person_name,
    rt.name AS type_name,
    d.auto_number,
    d.series,
    d.number,
    d.issue_date,
    d.expiry_date,
    d.issuer,
    CASE 
        WHEN d.expiry_date IS NULL THEN 'Unlimited'
        WHEN d.expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM document_register d
JOIN document_register_type rt ON rt.id = d.type_id
JOIN person p ON p.id = d.person_id
WHERE d.flags & 1 = 0  -- Не аннулирован
ORDER BY d.expiry_date;

CREATE OR REPLACE FUNCTION document_get_next_register_number(p_type_id INT)
RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
    v_next INT;
BEGIN
    SELECT code INTO v_code FROM document_register_type WHERE id = p_type_id;
    IF v_code IS NULL THEN
        RAISE EXCEPTION 'register type % has no code', p_type_id;
    END IF;
    SELECT COALESCE(MAX(
        CASE
            WHEN number ~ '([0-9]+)$' THEN (regexp_matches(number, '([0-9]+)$'))[1]::INT
            ELSE 0
        END
    ), 0) + 1
    INTO v_next
    FROM document_register
    WHERE type_id = p_type_id;

    RETURN v_code || '-' || LPAD(v_next::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION document_register_number_exists(p_type_id INT, p_number TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM document_register WHERE type_id = p_type_id AND number = p_number
    );
END;
$$ LANGUAGE plpgsql STABLE;
