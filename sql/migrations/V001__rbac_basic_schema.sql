-- RBAC Canon basic schema
-- Canonical RBAC main table
CREATE TABLE IF NOT EXISTS rbac_canon (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Roles associated with a canon
CREATE TABLE IF NOT EXISTS rbac_canon_roles (
  canon_id BIGINT NOT NULL REFERENCES rbac_canon(id),
  role TEXT NOT NULL,
  PRIMARY KEY (canon_id, role)
);

-- Permissions associated with a canon
CREATE TABLE IF NOT EXISTS rbac_canon_perms (
  canon_id BIGINT NOT NULL REFERENCES rbac_canon(id),
  permission TEXT NOT NULL,
  PRIMARY KEY (canon_id, permission)
);
