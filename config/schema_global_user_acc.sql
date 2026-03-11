-- =============================================================================
-- ГЛОБАЛЬНЫЕ ПОЛЬЗОВАТЕЛИ
-- Соответствуют Core.Auth.GlobalUserAcc
-- Аналог: PPOBJ_GLOBALUSERACC
-- =============================================================================

CREATE TABLE IF NOT EXISTS global_user_acc (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    email VARCHAR(256),
    flags INT DEFAULT 0,
    expire TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_global_user_acc_email ON global_user_acc(email);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_global_user_acc_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_global_user_acc_update
    BEFORE UPDATE ON global_user_acc
    FOR EACH ROW
    EXECUTE FUNCTION update_global_user_acc_timestamp();
