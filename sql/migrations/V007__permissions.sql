-- V007__permissions.sql
-- Normalized permissions and role-permission assignments

CREATE TABLE IF NOT EXISTS permission (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS role_permission (
    role_id BIGINT NOT NULL REFERENCES role(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permission(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id)
);

INSERT INTO permission (name, description)
VALUES
    ('read:persons', 'Read persons'),
    ('write:persons', 'Create or update persons'),
    ('delete:persons', 'Delete persons'),
    ('read:goods', 'Read goods'),
    ('write:goods', 'Create or update goods'),
    ('delete:goods', 'Delete goods'),
    ('read:bills', 'Read bills'),
    ('write:bills', 'Create or update bills'),
    ('delete:bills', 'Delete bills'),
    ('post:bills', 'Post bills'),
    ('read:payments', 'Read payments'),
    ('write:payments', 'Create or update payments'),
    ('delete:payments', 'Delete payments'),
    ('read:reports', 'Read reports'),
    ('write:reports', 'Create or update reports'),
    ('admin:rbac', 'Manage RBAC configuration')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON TRUE
WHERE r.name = 'admin'
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON p.name IN (
    'read:persons', 'read:goods', 'read:bills', 'read:payments', 'read:reports'
)
WHERE r.name = 'viewer'
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON p.name IN (
    'read:persons', 'write:persons',
    'read:goods', 'write:goods',
    'read:bills', 'write:bills',
    'read:payments', 'write:payments',
    'read:reports'
)
WHERE r.name = 'user'
ON CONFLICT DO NOTHING;
