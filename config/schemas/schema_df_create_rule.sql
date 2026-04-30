-- =============================================================================
-- ПРАВИЛА СОЗДАНИЯ ДРАФТ-ДОКУМЕНТОВ
-- Соответствуют Core.Document.DFCreateRule
-- Аналог: PPOBJ_DFCREATERULE
-- =============================================================================

CREATE TABLE IF NOT EXISTS df_create_rule (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    src_op_kind_id INT NOT NULL,
    dst_op_kind_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_df_create_rule_src ON df_create_rule(src_op_kind_id);
CREATE INDEX idx_df_create_rule_dst ON df_create_rule(dst_op_kind_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_df_create_rule_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_df_create_rule_update
    BEFORE UPDATE ON df_create_rule
    FOR EACH ROW
    EXECUTE FUNCTION update_df_create_rule_timestamp();
