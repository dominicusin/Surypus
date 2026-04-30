-- =============================================================================
-- РАБОЧИЕ ГРУППЫ
-- Соответствуют Core.HR.WorkingGroup
-- Аналог: PPOBJ_STAFFLIST2
-- =============================================================================

CREATE TABLE IF NOT EXISTS working_group (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    location_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_working_group_location ON working_group(location_id);

CREATE TABLE IF NOT EXISTS working_group_member (
    id SERIAL PRIMARY KEY,
    group_id INT NOT NULL REFERENCES working_group(id) ON DELETE CASCADE,
    person_id INT NOT NULL,
    since DATE NOT NULL,
    until DATE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_working_group_member_group ON working_group_member(group_id);
CREATE INDEX idx_working_group_member_person ON working_group_member(person_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_working_group_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_working_group_update
    BEFORE UPDATE ON working_group
    FOR EACH ROW
    EXECUTE FUNCTION update_working_group_timestamp();

CREATE TRIGGER trigger_working_group_member_update
    BEFORE UPDATE ON working_group_member
    FOR EACH ROW
    EXECUTE FUNCTION update_working_group_timestamp();

-- VIEW: Активные участники рабочих групп
CREATE OR REPLACE VIEW v_working_group_members AS
SELECT 
    wg.id AS group_id,
    wg.name AS group_name,
    wg.location_id,
    l.name AS location_name,
    wgm.person_id,
    p.name AS person_name,
    wgm.since,
    wgm.until
FROM working_group wg
JOIN working_group_member wgm ON wgm.group_id = wg.id
JOIN location l ON l.id = wg.location_id
JOIN person p ON p.id = wgm.person_id
WHERE wgm.until IS NULL OR wgm.until >= CURRENT_DATE
ORDER BY wg.name, p.name;
