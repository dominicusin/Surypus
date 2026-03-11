-- =============================================================================
-- СКЛАДСКИЕ ПАЛЛЕТЫ
-- Соответствуют Core.Warehouse.Pallet
-- Аналог: PPOBJ_PALLET
-- =============================================================================

CREATE TABLE IF NOT EXISTS pallet (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    location_id INT NOT NULL,
    status INT DEFAULT 0,  -- 0:Empty, 1:Loading, 2:Loaded, 3:InTransit, 4:AtCustomer
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_pallet_code ON pallet(code);
CREATE INDEX idx_pallet_location ON pallet(location_id);
CREATE INDEX idx_pallet_status ON pallet(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_pallet_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_pallet_update
    BEFORE UPDATE ON pallet
    FOR EACH ROW
    EXECUTE FUNCTION update_pallet_timestamp();