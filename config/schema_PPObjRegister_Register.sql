-- =============================================================================
-- РЕГИСТРАЦИОННЫЕ ДОКУМЕНТЫ — PPObjRegister
-- Соответствуют PPObjRegister
-- Используются для документации Core.Document.Register при миграции
-- =============================================================================

CREATE TABLE IF NOT EXISTS ppobj_register (
    id SERIAL PRIMARY KEY,
    person_id INT NOT NULL,
    type_id INT NOT NULL,
    series VARCHAR(32),
    number VARCHAR(64) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE,
    issuer VARCHAR(512),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ppobj_register_person ON ppobj_register(person_id);
CREATE INDEX idx_ppobj_register_type ON ppobj_register(type_id);
CREATE INDEX idx_ppobj_register_expiry ON ppobj_register(expiry_date);

CREATE OR REPLACE FUNCTION update_ppobj_register_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ppobj_register_update
    BEFORE UPDATE ON ppobj_register
    FOR EACH ROW
    EXECUTE FUNCTION update_ppobj_register_timestamp();

CREATE OR REPLACE VIEW v_ppobj_active_registers AS
SELECT 
    r.id,
    r.person_id,
    p.name AS person_name,
    rt.name AS type_name,
    r.series,
    r.number,
    r.issue_date,
    r.expiry_date,
    r.issuer,
    CASE 
        WHEN r.expiry_date IS NULL THEN 'Unlimited'
        WHEN r.expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS status
FROM ppobj_register r
JOIN document_register_type rt ON rt.id = r.type_id
JOIN person p ON p.id = r.person_id
WHERE r.flags & 1 = 0
ORDER BY r.expiry_date;
