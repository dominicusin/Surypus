-- ============================================================================
-- Advanced API Throttling & Quotas
-- ============================================================================

-- Quota definitions
CREATE TABLE IF NOT EXISTS api_quotas (
    id SERIAL PRIMARY KEY,
    quota_name TEXT UNIQUE NOT NULL,
    quota_type TEXT CHECK (quota_type IN ('daily', 'monthly', 'yearly')),
    limit_count INT NOT NULL,
    scope_type TEXT CHECK (scope_type IN ('user', 'tenant', 'api_key')),
    is_hard_limit BOOLEAN DEFAULT TRUE
);

-- Default quotas
INSERT INTO api_quotas (quota_name, quota_type, limit_count, scope_type)
VALUES 
    ('daily_events', 'daily', 100000, 'tenant'),
    ('monthly_events', 'monthly', 1000000, 'tenant'),
    ('daily_storage_mb', 'daily', 10240, 'tenant')
ON CONFLICT (quota_name) DO NOTHING;

-- Quota usage tracking
CREATE TABLE IF NOT EXISTS quota_usage (
    quota_id INT REFERENCES api_quotas(id),
    scope_id UUID NOT NULL,
    usage_count INT DEFAULT 0,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ,
    PRIMARY KEY(quota_id, scope_id, period_start)
);

-- Check quota
CREATE OR REPLACE FUNCTION check_quota(
    p_quota_name TEXT,
    p_scope_id UUID
) RETURNS TABLE(allowed BOOLEAN, remaining INT, reset_at TIMESTAMPTZ) AS $$
DECLARE
    v_quota RECORD;
    v_usage RECORD;
    v_remaining INT;
BEGIN
    SELECT * INTO v_quota FROM api_quotas WHERE quota_name = p_quota_name;
    
    IF v_quota IS NULL THEN
        RETURN QUERY SELECT TRUE, 999999999, NOW() + INTERVAL '1 day';
        RETURN;
    END IF;
    
    SELECT usage_count INTO v_usage
    FROM quota_usage
    WHERE quota_id = v_quota.id AND scope_id = p_scope_id
      AND (v_quota.quota_type = 'daily' AND period_start > NOW() - INTERVAL '1 day'
        OR v_quota.quota_type = 'monthly' AND period_start > NOW() - INTERVAL '30 days');
    
    v_remaining := v_quota.limit_count - COALESCE(v_usage.usage_count, 0);
    
    RETURN QUERY SELECT 
        v_remaining > 0, 
        GREATEST(0, v_remaining),
        NOW() + CASE v_quota.quota_type 
            WHEN 'daily' THEN INTERVAL '1 day'
            WHEN 'monthly' THEN INTERVAL '30 days'
            ELSE INTERVAL '1 day'
        END;
END;
$$ LANGUAGE plpgsql;

-- Consume quota
CREATE OR REPLACE FUNCTION consume_quota(
    p_quota_name TEXT,
    p_scope_id UUID,
    p_count INT DEFAULT 1
) RETURNS BOOLEAN AS $$
DECLARE
    v_quota RECORD;
    v_allowed BOOLEAN;
BEGIN
    SELECT allowed INTO v_allowed 
    FROM check_quota(p_quota_name, p_scope_id);
    
    IF NOT v_allowed THEN
        RETURN FALSE;
    END IF;
    
    -- Update usage
    SELECT * INTO v_quota FROM api_quotas WHERE quota_name = p_quota_name;
    
    INSERT INTO quota_usage (quota_id, scope_id, usage_count, period_start)
    VALUES (v_quota.id, p_scope_id, p_count, DATE_TRUNC('day', NOW()))
    ON CONFLICT (quota_id, scope_id, period_start) DO UPDATE SET
        usage_count = quota_usage.usage_count + p_count;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;