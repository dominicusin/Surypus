-- =============================================================================
-- ЭЛЕКТРОННЫЕ АДРЕСА
-- Соответствуют Core.Communication.EAddr
-- Аналог: PPOBJ_EADDR
-- =============================================================================

CREATE TABLE IF NOT EXISTS e_addr (
    id SERIAL PRIMARY KEY,
    owner_type INT NOT NULL,  -- PPOBJ_*
    owner_id INT NOT NULL,
    link_kind_id INT NOT NULL,
    address VARCHAR(512) NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_e_addr_owner ON e_addr(owner_type, owner_id);
CREATE INDEX idx_e_addr_link_kind ON e_addr(link_kind_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_e_addr_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_e_addr_update
    BEFORE UPDATE ON e_addr
    FOR EACH ROW
    EXECUTE FUNCTION update_e_addr_timestamp();
