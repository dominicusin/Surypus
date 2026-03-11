-- =============================================================================
-- ГРУППЫ СПИСАНИЯ АКТИВОВ
-- Соответствуют Core.Accounting.AssetWriteOffGroup
-- Аналог: PPOBJ_ASSTWROFFGRP
-- =============================================================================

CREATE TABLE IF NOT EXISTS asset_write_off_group (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO asset_write_off_group (id, name, symb) VALUES
(1, 'Материалы', 'MATERIALS'),
(2, 'Оборудование', 'EQUIPMENT'),
(3, 'Нематериальные активы', 'INTANGIBLE'),
(4, 'Основные средства', 'FIXED_ASSETS')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_asset_write_off_group_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_asset_write_off_group_update
    BEFORE UPDATE ON asset_write_off_group
    FOR EACH ROW
    EXECUTE FUNCTION update_asset_write_off_group_timestamp();
