-- V185: CRM RBAC permissions (Wave 3)
-- Adds 8 CRM-specific permissions and assigns them to the sales role

INSERT INTO permissions (code, name, description) VALUES
  ('crm.contacts.read',    'CRM: View contacts',       'Read access to CRM contacts'),
  ('crm.contacts.write',   'CRM: Manage contacts',     'Create/update/delete CRM contacts'),
  ('crm.companies.read',   'CRM: View companies',      'Read access to CRM companies'),
  ('crm.companies.write',   'CRM: Manage companies',    'Create/update/delete CRM companies'),
  ('crm.deals.read',       'CRM: View deals',          'Read access to CRM deals and pipeline'),
  ('crm.deals.write',       'CRM: Manage deals',        'Create/update/delete CRM deals'),
  ('crm.pipeline.manage',  'CRM: Manage pipeline',      'Configure pipeline stages and rules'),
  ('crm.activities.write', 'CRM: Log activities',      'Create activities on contacts and deals')
ON CONFLICT (name) DO NOTHING;

-- Assign all CRM permissions to the 'sales' role (create if missing)
INSERT INTO roles (name, description) VALUES
  ('sales', 'Sales team — full CRM access')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'sales'
  AND p.code LIKE 'crm.%'
ON CONFLICT DO NOTHING;

-- Also give 'admin' role all CRM permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin'
  AND p.code LIKE 'crm.%'
ON CONFLICT DO NOTHING;
