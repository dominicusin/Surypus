-- Multi-Tenant: Tenants table
CREATE TABLE IF NOT EXISTS tenants (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  schema_name TEXT NOT NULL DEFAULT 'public',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  features JSONB DEFAULT '{}',
  branding JSONB DEFAULT '{}',
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenants_slug ON tenants (slug);
CREATE INDEX IF NOT EXISTS idx_tenants_active ON tenants (is_active);

-- Add tenant_id to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS tenant_id BIGINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_users_tenant ON users (tenant_id);

-- Insert default tenant for existing data
INSERT INTO tenants (id, name, slug, schema_name, is_active)
VALUES (0, 'Default Tenant', 'default', 'public', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Seed the sequence
SELECT setval('tenants_id_seq', GREATEST(1, (SELECT MAX(id) FROM tenants)));
