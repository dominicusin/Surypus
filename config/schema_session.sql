-- Session Tables
CREATE TABLE IF NOT EXISTS session (id BIGSERIAL PRIMARY KEY, session_id VARCHAR(64) NOT NULL, user_id BIGINT NOT NULL, started_at TIMESTAMPTZ DEFAULT NOW(), expires_at TIMESTAMPTZ, data JSONB, UNIQUE(session_id));
CREATE INDEX IF NOT EXISTS idx_session_user ON session(user_id);
