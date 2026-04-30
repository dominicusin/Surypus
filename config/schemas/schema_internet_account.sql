-- =============================================================================
-- ПОЧТОВЫЕ УЧЁТНЫЕ ЗАПИСИ
-- Соответствуют Core.Integration.InternetAccount
-- Аналог: PPOBJ_INTERNETACCOUNT
-- =============================================================================

CREATE TABLE IF NOT EXISTS internet_account (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    email VARCHAR(256) NOT NULL,
    smtp_host VARCHAR(256),
    smtp_port INT DEFAULT 25 CHECK (smtp_port >= 0 AND smtp_port <= 65535),
    imap_host VARCHAR(256),
    imap_port INT DEFAULT 143 CHECK (imap_port >= 0 AND imap_port <= 65535),
    username VARCHAR(256),
    password VARCHAR(512),  -- Зашифрованный
    flags INT DEFAULT 0,
    loc_id INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_internet_account_email ON internet_account(email);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_internet_account_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_internet_account_update
    BEFORE UPDATE ON internet_account
    FOR EACH ROW
    EXECUTE FUNCTION update_internet_account_timestamp();
