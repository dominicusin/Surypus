-- Document workflow
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    doc_type TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT DEFAULT 'DRAFT',
    file_path TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TYPE doc_status AS ENUM ('draft', 'finalized', 'archived');
