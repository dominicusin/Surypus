-- V006__roles.sql
-- Normalized RBAC role storage

CREATE TABLE IF NOT EXISTS role (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_role (
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES role(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_user_role_role_id ON user_role(role_id);

INSERT INTO role (name, description)
VALUES
    ('admin', 'Full access to all protected endpoints'),
    ('user', 'Standard authenticated user'),
    ('viewer', 'Read-only access')
ON CONFLICT (name) DO NOTHING;
