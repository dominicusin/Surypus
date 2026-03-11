-- =============================================================================
-- ДОЛЖНОСТНЫЕ НАЗНАЧЕНИЯ
-- Соответствуют Core.HR.PersonPost
-- Аналог: PPOBJ_PERSONPOST
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_post (
    id SERIAL PRIMARY KEY,
    person_id INT NOT NULL,
    location_id INT NOT NULL,
    position VARCHAR(256),
    start_date DATE NOT NULL,
    end_date DATE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_person_post_person ON person_post(person_id);
CREATE INDEX idx_person_post_location ON person_post(location_id);
CREATE INDEX idx_person_post_dates ON person_post(start_date, end_date);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_person_post_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_person_post_update
    BEFORE UPDATE ON person_post
    FOR EACH ROW
    EXECUTE FUNCTION update_person_post_timestamp();

-- VIEW: Активные должности
CREATE OR REPLACE VIEW v_active_person_posts AS
SELECT 
    pp.id,
    pp.person_id,
    p.name AS person_name,
    pp.location_id,
    l.name AS location_name,
    pp.position,
    pp.start_date,
    pp.end_date
FROM person_post pp
JOIN person p ON p.id = pp.person_id
JOIN location l ON l.id = pp.location_id
WHERE pp.end_date IS NULL OR pp.end_date >= CURRENT_DATE
ORDER BY pp.person_id, pp.start_date DESC;
