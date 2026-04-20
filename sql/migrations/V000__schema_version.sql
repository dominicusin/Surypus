-- Create schema_version table to track applied migrations
CREATE TABLE IF NOT EXISTS schema_version (
    version VARCHAR(50) NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT
);

-- Insert a row for the initial version (if not already present)
INSERT INTO schema_version (version, description)
SELECT 'V000__schema_version', 'Initial schema version table'
WHERE NOT EXISTS (
    SELECT 1 FROM schema_version WHERE version = 'V000__schema_version'
);