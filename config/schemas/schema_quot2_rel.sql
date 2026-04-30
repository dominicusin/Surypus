-- =============================================================================
-- ГРУППИРУЮЩИЕ ХАРАКТЕРИСТИКИ КОТИРОВОК v2
-- Соответствуют Core.Pricing.Quot2Rel
-- Аналог: PPOBJ_QUOT2REL
-- =============================================================================

CREATE TABLE IF NOT EXISTS quot2_rel (
    id SERIAL PRIMARY KEY,
    quot_id INT NOT NULL,
    rel_type INT NOT NULL,  -- 1:Товар, 2:Группа, 3:Бренд
    rel_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_quot2_rel_quot ON quot2_rel(quot_id);
CREATE INDEX idx_quot2_rel_rel ON quot2_rel(rel_type, rel_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_quot2_rel_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quot2_rel_update
    BEFORE UPDATE ON quot2_rel
    FOR EACH ROW
    EXECUTE FUNCTION update_quot2_rel_timestamp();
