-- Ensure Role_Admin has inventory_write permission (idempotent safety)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM roles WHERE name = 'Role_Admin') THEN
    IF EXISTS (SELECT 1 FROM permissions WHERE code = 'inventory_write') THEN
      IF NOT EXISTS (
          SELECT 1
          FROM role_permissions rp
          JOIN roles r ON rp.role_id = r.id
          WHERE r.name = 'Role_Admin' AND rp.permission_id = (SELECT id FROM permissions WHERE code = 'inventory_write')
      ) THEN
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id
        FROM roles r, permissions p
        WHERE r.name = 'Role_Admin' AND p.code = 'inventory_write'
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;
  END IF;
END $$ LANGUAGE plpgsql;
