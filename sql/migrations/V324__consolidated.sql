-- Migration V324: Consolidated RBAC canonical finalization
-- Original files: V324__rbac_canonical_finalization_cleanup.sql, V324__rbac_canonical_finalization_views.sql

-- Create canonical finalization view
CREATE OR REPLACE VIEW v_rbac_canonical AS
SELECT r.id, r.name, p.code
FROM roles r
LEFT JOIN role_permissions rp ON r.id = rp.role_id
LEFT JOIN permissions p ON rp.permission_id = p.id;

-- Cleanup old role entries
DELETE FROM roles WHERE name LIKE '%Old%';
