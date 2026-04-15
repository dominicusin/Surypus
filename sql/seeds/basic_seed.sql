-- Seed initial data for Phase 2 MVP
-- Roles
INSERT INTO roles (name) VALUES ('admin'), ('accountant'), ('viewer') ON CONFLICT DO NOTHING;

-- Permissions (example)
INSERT INTO permissions (name) VALUES (
  'accounts:read'), ('accounts:write'),
  ('journals:read'), ('journals:write'),
  ('bills:read'), ('bills:write'),
  ('payments:read'), ('payments:write'),
  ('users:read'), ('users:write')
) ON CONFLICT DO NOTHING;

-- User seeds
INSERT INTO users (username, password_hash, email, is_active, created_at, updated_at)
VALUES ('admin', 'hashed','admin@example.com', true, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- User roles
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE u.username = 'admin' AND r.name = 'admin';

-- Accounts seed
INSERT INTO accounts (code, name, type, currency, description, is_active, created_at, updated_at)
VALUES ('4001', 'Cash', 'Asset', 'USD', 'Cash on hand', true, NOW(), NOW()),
       ('5001', 'Revenue', 'Income', 'USD', 'Sales revenue', true, NOW(), NOW())
ON CONFLICT DO NOTHING;
