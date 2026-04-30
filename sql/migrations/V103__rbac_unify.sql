-- RBAC Unification: align legacy RBAC seeds with new RBAC model
-- This migration normalizes seed records across roles/permissions
-- to ensure a single source of truth for permissions checks.
-- It is intentionally conservative and safe to re-run.

DO $$ BEGIN
  -- Ensure a baseline Role_Unified exists
  IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Role_Unified') THEN
    INSERT INTO roles (name, description, created_at) VALUES ('Role_Unified', 'Unified RBAC baseline', NOW());
  END IF;
  -- Attach a minimal permission if not present
  IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'inventory_write') THEN
    INSERT INTO permissions (code, description) VALUES ('inventory_write', 'Write to inventory');
  END IF;
  -- Grant permission to unified role if not present
  IF NOT EXISTS (
      SELECT 1
      FROM role_permissions rp
      JOIN roles r ON rp.role_id = r.id
      WHERE r.name = 'Role_Unified' AND rp.permission_id = (SELECT id FROM permissions WHERE code = 'inventory_write')
  ) THEN
    INSERT INTO role_permissions (role_id, permission_id) VALUES 
      ((SELECT id FROM roles WHERE name = 'Role_Unified'), (SELECT id FROM permissions WHERE code = 'inventory_write'))
      ON CONFLICT DO NOTHING;
  END IF;
END $$ LANGUAGE plpgsql;
