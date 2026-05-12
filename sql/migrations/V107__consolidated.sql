-- Migration V107: Consolidated RBAC compatibility check and seed unify
-- Original files: V107__rbac_compat_check.sql, V107__rbac_seed_unify.sql

-- RBAC Compatibility Check
DO $$ BEGIN
    -- Update deprecated role names if needed
    UPDATE roles SET name = 'Role_Unified' WHERE name IN ('Role_Old', 'Legacy_Role');
    
    -- Ensure all roles have descriptions
    UPDATE roles SET description = 'Legacy role - needs review' WHERE description IS NULL;
END $$ LANGUAGE plpgsql;

-- RBAC Seed Unify
DO $$ BEGIN
    -- Normalize seed role data
    INSERT INTO roles (name, description, created_at)
    SELECT DISTINCT role_name, 'Seed role', NOW()
    FROM (VALUES ('viewer'), ('user'), ('manager'), ('admin')) AS roles(role_name)
    WHERE NOT EXISTS (SELECT 1 FROM roles WHERE name = role_name);
END $$ LANGUAGE plpgsql;
