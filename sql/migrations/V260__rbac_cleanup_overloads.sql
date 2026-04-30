-- Remove duplicate overload of has_permission_compat to keep a single canonical signature
DROP FUNCTION IF EXISTS has_permission_compat(bigint, text, uuid);
DROP FUNCTION IF EXISTS has_permission_compat(bigint, text, uuid) CASCADE;
