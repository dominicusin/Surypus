-- =============================================================================
-- ПРОФИЛИ ПОЛЬЗОВАТЕЛЕЙ
-- Соответствуют Core.Auth.UserProfile
-- Аналог: PPOBJ_USERPROFILE
-- =============================================================================

CREATE TABLE IF NOT EXISTS user_profile (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(256) NOT NULL,
    config JSONB,
    last_login TIMESTAMP,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_profile_user ON user_profile(user_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_user_profile_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_profile_update
    BEFORE UPDATE ON user_profile
    FOR EACH ROW
    EXECUTE FUNCTION update_user_profile_timestamp();
