-- =============================================================================
-- ШАБЛОНЫ БИЗНЕС-ПОКАЗАТЕЛЕЙ
-- Соответствуют Core.BizScore.BizScoreTempl
-- Аналог: PPOBJ_BIZSCTEMPL
-- =============================================================================

CREATE TABLE IF NOT EXISTS bizscore_template (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    formula TEXT,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_bizscore_template_code ON bizscore_template(code) WHERE code IS NOT NULL;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_bizscore_template_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_bizscore_template_update
    BEFORE UPDATE ON bizscore_template
    FOR EACH ROW
    EXECUTE FUNCTION update_bizscore_template_timestamp();
