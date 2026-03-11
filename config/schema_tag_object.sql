-- =============================================================================
-- ТЕГИ ОБЪЕКТОВ
-- Соответствуют Core.Common.Tag
-- Аналог: PPOBJ_TAG
-- =============================================================================

CREATE TABLE IF NOT EXISTS tag (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    type_id INT DEFAULT 0,  -- PPOBJ_*
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tag_type ON tag(type_id);
CREATE UNIQUE INDEX idx_tag_symb ON tag(symb) WHERE symb IS NOT NULL;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_tag_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_tag_update
    BEFORE UPDATE ON tag
    FOR EACH ROW
    EXECUTE FUNCTION update_tag_timestamp();
