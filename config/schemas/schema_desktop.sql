-- =============================================================================
-- РАБОЧИЕ СТОЛЫ
-- Соответствуют Core.UI.Desktop
-- Аналог: PPOBJ_DESKTOP
-- =============================================================================

CREATE TABLE IF NOT EXISTS desktop (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    owner_id INT NOT NULL,
    config JSONB,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_desktop_owner ON desktop(owner_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_desktop_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_desktop_update
    BEFORE UPDATE ON desktop
    FOR EACH ROW
    EXECUTE FUNCTION update_desktop_timestamp();
