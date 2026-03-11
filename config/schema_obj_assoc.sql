-- =============================================================================
-- АССОЦИАЦИИ ОБЪЕКТОВ
-- Соответствуют Core.Common.ObjAssoc
-- Аналог: PPOBJ_OBJASSOC
-- =============================================================================

CREATE TABLE IF NOT EXISTS obj_assoc (
    id SERIAL PRIMARY KEY,
    src_type INT NOT NULL,
    src_id INT NOT NULL,
    dst_type INT NOT NULL,
    dst_id INT NOT NULL,
    assoc_type INT DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_obj_assoc_src ON obj_assoc(src_type, src_id);
CREATE INDEX idx_obj_assoc_dst ON obj_assoc(dst_type, dst_id);
CREATE UNIQUE INDEX idx_obj_assoc_unique ON obj_assoc(src_type, src_id, dst_type, dst_id, assoc_type);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_obj_assoc_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_obj_assoc_update
    BEFORE UPDATE ON obj_assoc
    FOR EACH ROW
    EXECUTE FUNCTION update_obj_assoc_timestamp();
