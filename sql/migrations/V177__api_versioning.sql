-- ============================================================================
-- API Versioning
-- ============================================================================

-- API version registry
CREATE TABLE IF NOT EXISTS api_versions (
    id SERIAL PRIMARY KEY,
    version TEXT NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    is_deprecated BOOLEAN DEFAULT FALSE,
    deprecation_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Default versions
INSERT INTO api_versions (version, is_active, is_deprecated)
VALUES 
    ('v1', TRUE, TRUE),
    ('v2', TRUE, FALSE)
ON CONFLICT (version) DO NOTHING;

-- API version check
CREATE OR REPLACE FUNCTION check_api_version(
    p_version TEXT
) RETURNS TABLE(version TEXT, is_active BOOLEAN, is_deprecated BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    SELECT av.version, av.is_active, av.is_deprecated
    FROM api_versions av
    WHERE av.version = p_version AND av.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Version-specific rate limits
ALTER TABLE rate_limit_config ADD COLUMN IF NOT EXISTS api_version TEXT;

UPDATE rate_limit_config
SET api_version = 'v2'
WHERE api_version IS NULL;

-- Feature flags
CREATE TABLE IF NOT EXISTS feature_flags (
    id SERIAL PRIMARY KEY,
    flag_name TEXT UNIQUE NOT NULL,
    enabled_for_tenants UUID[],
    disabled_for_tenants UUID[],
    enabled_by_default BOOLEAN DEFAULT TRUE,
    rollout_percentage INT DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE
);

-- Check feature flag
CREATE OR REPLACE FUNCTION is_feature_enabled(
    p_flag_name TEXT,
    p_tenant_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_flag RECORD;
BEGIN
    SELECT * INTO v_flag FROM feature_flags WHERE flag_name = p_flag_name AND is_active = TRUE;
    
    IF v_flag IS NULL THEN
        RETURN TRUE;  -- Unknown flags are enabled
    END IF;
    
    -- Check tenant-specific
    IF p_tenant_id IS NOT NULL THEN
        IF p_tenant_id = ANY(v_flag.enabled_for_tenants) THEN
            RETURN TRUE;
        END IF;
        IF p_tenant_id = ANY(v_flag.disabled_for_tenants) THEN
            RETURN FALSE;
        END IF;
    END IF;
    
    -- Rollout percentage
    IF v_flag.rollout_percentage < 100 THEN
        RETURN (p_tenant_id::TEXT::BIGINT % 100) < v_flag.rollout_percentage;
    END IF;
    
    RETURN v_flag.enabled_by_default;
END;
$$ LANGUAGE plpgsql;