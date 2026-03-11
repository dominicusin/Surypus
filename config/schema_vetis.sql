-- =============================================================================
-- VETIS (ВЕТИС)
-- Соответствуют Core.Trade.VETIS
-- Аналог: PPOBJ_VETISENTITY
-- =============================================================================

CREATE TABLE IF NOT EXISTS vetis_entity (
    id SERIAL PRIMARY KEY,
    entity_type INT NOT NULL,  -- 1:Producer, 2:Enterprise, 3:Product, 4:VetDocument, 5:Stock
    uuid VARCHAR(36) NOT NULL,
    guid VARCHAR(36),
    json_data JSONB,
    status INT DEFAULT 0,  -- 0:New, 1:Sent, 2:Confirmed, 3:Rejected, 4:Archived
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_vetis_entity_type ON vetis_entity(entity_type);
CREATE INDEX idx_vetis_entity_uuid ON vetis_entity(uuid);
CREATE INDEX idx_vetis_entity_guid ON vetis_entity(guid);
CREATE INDEX idx_vetis_entity_status ON vetis_entity(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_vetis_entity_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_vetis_entity_update
    BEFORE UPDATE ON vetis_entity
    FOR EACH ROW
    EXECUTE FUNCTION update_vetis_entity_timestamp();

-- VIEW: Статистика VETIS
CREATE OR REPLACE VIEW v_vetis_stats AS
SELECT 
    entity_type,
    CASE entity_type
        WHEN 1 THEN 'Producer'
        WHEN 2 THEN 'Enterprise'
        WHEN 3 THEN 'Product'
        WHEN 4 THEN 'VetDocument'
        WHEN 5 THEN 'Stock'
    END AS entity_type_name,
    COUNT(*) AS total,
    COUNT(CASE WHEN status = 0 THEN 1 END) AS new_count,
    COUNT(CASE WHEN status = 1 THEN 1 END) AS sent_count,
    COUNT(CASE WHEN status = 2 THEN 1 END) AS confirmed_count,
    COUNT(CASE WHEN status = 3 THEN 1 END) AS rejected_count
FROM vetis_entity
GROUP BY entity_type;
