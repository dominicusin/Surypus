-- =============================================================================
-- ТИПЫ ТОВАРНЫХ УПАКОВОК
-- Соответствуют Core.Logistics.PackageType
-- Аналог: PPOBJ_PCKGTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS package_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    capacity NUMERIC(18,6) DEFAULT 1 CHECK (capacity > 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO package_type (id, name, symb, capacity) VALUES
(1, 'Штука', 'PCE', 1),
(2, 'Упаковка', 'PACK', 10),
(3, 'Коробка', 'BOX', 50),
(4, 'Поддон', 'PALLET', 100)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_package_type_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_package_type_update
    BEFORE UPDATE ON package_type
    FOR EACH ROW
    EXECUTE FUNCTION update_package_type_timestamp();
