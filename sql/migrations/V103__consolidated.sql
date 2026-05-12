-- Migration V103: Consolidated ledger index and RBAC unification
-- Original files: V103__index_ledger_entry_ref.sql, V103__rbac_unify.sql

-- Add index to speed up ledger lookups by ref_type/ref_id
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_entry_ref ON ledger_entry (ref_type, ref_id);

-- RBAC Unification: align legacy RBAC seeds with new RBAC model
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
