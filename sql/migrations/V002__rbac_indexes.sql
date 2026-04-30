-- Add indexes to RBAC Canon tables to improve lookups
CREATE INDEX IF NOT EXISTS idx_rbac_canon_name ON rbac_canon (name);
CREATE INDEX IF NOT EXISTS idx_rbac_canon_roles_canon ON rbac_canon_roles (canon_id);
CREATE INDEX IF NOT EXISTS idx_rbac_canon_perms ON rbac_canon_perms (canon_id);
