-- =============================================================================
-- ПОДШИВКА STYLO-Q
-- Соответствуют Core.Integration.StyloQBinery
-- Аналог: PPOBJ_STYLOQBINDERY
-- =============================================================================

CREATE TABLE IF NOT EXISTS styloq_binery (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    uuid VARCHAR(64) NOT NULL,
    owner_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_styloq_binery_uuid ON styloq_binery(uuid);
CREATE INDEX idx_styloq_binery_owner ON styloq_binery(owner_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_styloq_binery_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_styloq_binery_update
    BEFORE UPDATE ON styloq_binery
    FOR EACH ROW
    EXECUTE FUNCTION update_styloq_binery_timestamp();
