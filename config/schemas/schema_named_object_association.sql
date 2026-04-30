-- =============================================================================
-- ИМЕНОВАННЫЕ АССОЦИАЦИИ ОБЪЕКТОВ
-- Соответствуют Core.Common.NamedObjectAssociation
-- Аналог: PPOBJ_NAMEDOBJASSOC
-- =============================================================================

CREATE TABLE IF NOT EXISTS named_object_association (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    source_type INT NOT NULL,  -- PPOBJ_*
    source_id INT NOT NULL,
    target_type INT NOT NULL,  -- PPOBJ_*
    target_id INT NOT NULL,
    flags INT DEFAULT 0,
    priority INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_noa_different_objects CHECK (source_type != target_type OR source_id != target_id)
);

CREATE INDEX idx_noa_source ON named_object_association(source_type, source_id);
CREATE INDEX idx_noa_target ON named_object_association(target_type, target_id);
CREATE UNIQUE INDEX idx_noa_unique ON named_object_association(source_type, source_id, target_type, target_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_named_object_association_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_named_object_association_update
    BEFORE UPDATE ON named_object_association
    FOR EACH ROW
    EXECUTE FUNCTION update_named_object_association_timestamp();

-- FUNCTION: Получить связанные объекты
CREATE OR REPLACE FUNCTION get_associated_objects(p_source_type INT, p_source_id INT, p_target_type INT DEFAULT NULL)
RETURNS TABLE (
    id INT,
    name TEXT,
    target_id INT,
    priority INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        noa.id,
        noa.name,
        noa.target_id,
        noa.priority
    FROM named_object_association noa
    WHERE noa.source_type = p_source_type 
      AND noa.source_id = p_source_id
      AND (p_target_type IS NULL OR noa.target_type = p_target_type)
    ORDER BY noa.priority, noa.name;
END;
$$ LANGUAGE plpgsql;

-- VIEW: Все ассоциации с человеческими именами типов
CREATE OR REPLACE VIEW v_named_object_associations AS
SELECT 
    noa.id,
    noa.name,
    noa.source_type,
    noa.target_type,
    noa.source_id,
    noa.target_id,
    noa.priority,
    CASE noa.source_type
        WHEN 1004 THEN 'person'
        WHEN 1008 THEN 'goodsgroup'
        WHEN 1009 THEN 'goods'
        WHEN 1010 THEN 'location'
        WHEN 1011 THEN 'bill'
        WHEN 1031 THEN 'scard'
        ELSE 'unknown'
    END AS source_type_name,
    CASE noa.target_type
        WHEN 1004 THEN 'person'
        WHEN 1008 THEN 'goodsgroup'
        WHEN 1009 THEN 'goods'
        WHEN 1010 THEN 'location'
        WHEN 1011 THEN 'bill'
        WHEN 1031 THEN 'scard'
        ELSE 'unknown'
    END AS target_type_name
FROM named_object_association noa;
