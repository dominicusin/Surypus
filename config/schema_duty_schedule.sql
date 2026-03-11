-- =============================================================================
-- РАСПИСАНИЯ ДЕЖУРСТВ
-- Соответствуют Core.HR.DutySchedule
-- Аналог: PPOBJ_DUTYSCHED
-- =============================================================================

CREATE TABLE IF NOT EXISTS duty_schedule (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    person_id INT NOT NULL,
    flags INT DEFAULT 0,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    pattern JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_duty_schedule_dates CHECK (start_date <= end_date)
);

CREATE INDEX idx_duty_schedule_person ON duty_schedule(person_id);
CREATE INDEX idx_duty_schedule_dates ON duty_schedule(start_date, end_date);

CREATE TABLE IF NOT EXISTS duty_schedule_event (
    id SERIAL PRIMARY KEY,
    schedule_id INT NOT NULL REFERENCES duty_schedule(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location_id INT DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_duty_event_times CHECK (start_time <= end_time)
);

CREATE INDEX idx_duty_schedule_event_schedule ON duty_schedule_event(schedule_id);
CREATE INDEX idx_duty_schedule_event_date ON duty_schedule_event(date);
CREATE UNIQUE INDEX idx_duty_schedule_event_unique ON duty_schedule_event(schedule_id, date) WHERE flags & 1 = 0;

-- TRIGGERS
CREATE OR REPLACE FUNCTION update_duty_schedule_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_duty_schedule_update
    BEFORE UPDATE ON duty_schedule
    FOR EACH ROW
    EXECUTE FUNCTION update_duty_schedule_timestamp();

CREATE TRIGGER trigger_duty_schedule_event_update
    BEFORE UPDATE ON duty_schedule_event
    FOR EACH ROW
    EXECUTE FUNCTION update_duty_schedule_timestamp();

-- VIEWS
CREATE OR REPLACE VIEW v_duty_schedule_calendar AS
SELECT 
    dse.id,
    dse.schedule_id,
    ds.name AS schedule_name,
    ds.person_id,
    p.name AS person_name,
    dse.date,
    dse.start_time,
    dse.end_time,
    dse.location_id,
    l.name AS location_name
FROM duty_schedule_event dse
JOIN duty_schedule ds ON ds.id = dse.schedule_id
LEFT JOIN person p ON p.id = ds.person_id
LEFT JOIN location l ON l.id = dse.location_id
WHERE ds.start_date <= dse.date AND ds.end_date >= dse.date
ORDER BY dse.date, dse.start_time;
