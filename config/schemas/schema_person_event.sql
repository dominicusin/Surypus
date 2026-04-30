-- =============================================================================
-- ПЕРСОНАЛЬНЫЕ СОБЫТИЯ
-- Соответствуют Core.People.PersonEvent
-- Аналог: PPOBJ_PERSONEVENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_event (
    id SERIAL PRIMARY KEY,
    person_id INT NOT NULL,
    event_kind_id INT NOT NULL,
    date DATE NOT NULL,
    flags INT DEFAULT 0,
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_person_event_person ON person_event(person_id);
CREATE INDEX idx_person_event_date ON person_event(date);
CREATE INDEX idx_person_event_kind ON person_event(event_kind_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_person_event_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_person_event_update
    BEFORE UPDATE ON person_event
    FOR EACH ROW
    EXECUTE FUNCTION update_person_event_timestamp();
