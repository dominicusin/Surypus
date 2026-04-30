-- =============================================================================
-- ВИДЫ АДРЕСОВ ЭЛЕКТРОННОЙ СВЯЗИ
-- Соответствуют Core.Communication.ELinkKind
-- Аналог: PPOBJ_ELINKKIND
-- =============================================================================

CREATE TABLE IF NOT EXISTS e_link_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO e_link_kind (id, name, symb) VALUES
(1, 'Email', 'EMAIL'),
(2, 'Телефон', 'PHONE'),
(3, 'Web-сайт', 'WEB'),
(4, 'ICQ', 'ICQ'),
(5, 'Skype', 'SKYPE'),
(6, 'Telegram', 'TELEGRAM'),
(7, 'WhatsApp', 'WHATSAPP')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_e_link_kind_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_e_link_kind_update
    BEFORE UPDATE ON e_link_kind
    FOR EACH ROW
    EXECUTE FUNCTION update_e_link_kind_timestamp();
