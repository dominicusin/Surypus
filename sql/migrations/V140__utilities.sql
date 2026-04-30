-- Utilities for common operations

-- Safe JSON merge with validation
CREATE OR REPLACE FUNCTION jsonb_merge_safe(
    p_base JSONB,
    p_update JSONB,
    p_required_keys TEXT[] DEFAULT '{}'
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    v_result := p_base || p_update;
    
    IF p_required_keys IS NOT NULL AND array_length(p_required_keys, 1) > 0 THEN
        IF NOT validate_json_keys(v_result, p_required_keys) THEN
            RAISE EXCEPTION 'Missing required keys in JSON';
        END IF;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Tenant context helper
CREATE OR REPLACE FUNCTION current_tenant_id() RETURNS UUID AS $$
BEGIN
    RETURN current_setting('surypus.tenant_id', true)::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- User context helper  
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
BEGIN
    RETURN current_setting('surypus.user_id', true)::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Batch event append helper
CREATE OR REPLACE FUNCTION event_append_batch(
    p_events JSONB
) RETURNS INT AS $$
DECLARE
    v_event JSONB;
    v_count INT := 0;
BEGIN
    FOR v_event IN SELECT * FROM jsonb_array_elements(p_events)
    LOOP
        PERFORM event_append(
            (v_event->>'aggregate_id')::UUID,
            v_event->>'aggregate_type',
            v_event->>'event_type',
            v_event->'event_data',
            (v_event->>'tenant_id')::UUID,
            NULL, NULL, NULL, NULL
        );
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;