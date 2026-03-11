-- =============================================================================
-- ДОЛЖНОСТНЫЕ ЗВАНИЯ
-- Соответствуют Core.HR.StaffRank
-- Аналог: PPOBJ_STAFFRANK
-- =============================================================================

CREATE TABLE IF NOT EXISTS staff_rank (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    priority INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO staff_rank (id, name, symb, priority) VALUES
(1, 'Стажёр', 'INTERN', 1),
(2, 'Младший специалист', 'JUNIOR', 2),
(3, 'Специалист', 'MIDDLE', 3),
(4, 'Старший специалист', 'SENIOR', 4),
(5, 'Ведущий специалист', 'LEAD', 5),
(6, 'Руководитель', 'MANAGER', 6),
(7, 'Директор', 'DIRECTOR', 7)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_staff_rank_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_staff_rank_update
    BEFORE UPDATE ON staff_rank
    FOR EACH ROW
    EXECUTE FUNCTION update_staff_rank_timestamp();
