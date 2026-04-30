-- Additional RBAC seed harmonization: ensure all roles have consistent permission mappings
DO $$ BEGIN
  -- Ensure Role_Unified exists
  IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Role_Unified') THEN
    INSERT INTO roles (name, description, created_at) VALUES ('Role_Unified', 'Unified RBAC baseline', NOW());
  END IF;
  -- Ensure Role_Admin exists
  IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Role_Admin') THEN
    INSERT INTO roles (name, description, created_at) VALUES ('Role_Admin', 'Administrative role', NOW());
  END IF;
  -- Ensure inventory_write permission exists
  IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'inventory_write') THEN
    INSERT INTO permissions (code, description) VALUES ('inventory_write', 'Write to inventory');
  END IF;
  -- Link Role_Admin to inventory_write if not linked
  IF NOT EXISTS (
      SELECT 1 FROM role_permissions rp
      JOIN roles r ON rp.role_id = r.id
      WHERE r.name = 'Role_Admin' AND rp.permission_id = (SELECT id FROM permissions WHERE code = 'inventory_write')
  ) THEN
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = 'Role_Admin' AND p.code = 'inventory_write'
    ON CONFLICT DO NOTHING;
  END IF;
END $$ LANGUAGE plpgsql;
