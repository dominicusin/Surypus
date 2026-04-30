-- =============================================================================
-- РАЗДЕЛЫ БАЗЫ ДАННЫХ
-- Соответствуют Core.Common.DbDiv
-- Аналог: PPOBJ_DBDIV
-- =============================================================================

CREATE TABLE IF NOT EXISTS db_div (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    priority INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_db_div_symb ON db_div(symb) WHERE symb IS NOT NULL;

-- DEFAULT DATA
INSERT INTO db_div (id, name, symb, priority) VALUES
(1, 'Основной раздел', 'MAIN', 1)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_db_div_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_db_div_update
    BEFORE UPDATE ON db_div
    FOR EACH ROW
    EXECUTE FUNCTION update_db_div_timestamp();
