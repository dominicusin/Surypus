-- =============================================================================
-- ПРОВАЙДЕРЫ EDI
-- Соответствуют Core.Integration.EDIProvider
-- Аналог: PPOBJ_EDIPROVIDER
-- =============================================================================

CREATE TABLE IF NOT EXISTS edi_provider (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    api_url VARCHAR(512),
    api_key VARCHAR(512),
    config JSONB,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS edi_document (
    id SERIAL PRIMARY KEY,
    provider_id INT NOT NULL REFERENCES edi_provider(id),
    doc_type VARCHAR(64) NOT NULL,
    direction INT NOT NULL,  -- 0:Incoming, 1:Outgoing
    status INT DEFAULT 0,  -- 0:New, 1:Sent, 2:Delivered, 3:Error
    content TEXT,
    ext_id VARCHAR(128),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_edi_document_provider ON edi_document(provider_id);
CREATE INDEX idx_edi_document_status ON edi_document(status);
CREATE INDEX idx_edi_document_direction ON edi_document(direction);
CREATE INDEX idx_edi_document_ext_id ON edi_document(ext_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_edi_provider_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_edi_provider_update
    BEFORE UPDATE ON edi_provider
    FOR EACH ROW
    EXECUTE FUNCTION update_edi_provider_timestamp();

CREATE TRIGGER trigger_edi_document_update
    BEFORE UPDATE ON edi_document
    FOR EACH ROW
    EXECUTE FUNCTION update_edi_provider_timestamp();

-- VIEW: Статистика EDI
CREATE OR REPLACE VIEW v_edi_stats AS
SELECT 
    ep.id,
    ep.name AS provider_name,
    COUNT(ed.id) AS total_docs,
    COUNT(CASE WHEN ed.status = 0 THEN 1 END) AS new_docs,
    COUNT(CASE WHEN ed.status = 1 THEN 1 END) AS sent_docs,
    COUNT(CASE WHEN ed.status = 2 THEN 1 END) AS delivered_docs,
    COUNT(CASE WHEN ed.status = 3 THEN 1 END) AS error_docs
FROM edi_provider ep
LEFT JOIN edi_document ed ON ed.provider_id = ep.id
GROUP BY ep.id, ep.name;
