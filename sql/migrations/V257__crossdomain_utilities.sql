-- ============================================================================
-- Phase 5: Cross-Domain Utilities & Final Optimizations
-- ============================================================================

-- ============================================================================
-- CROSS-DOMAIN: Event Correlation & Aggregation
-- ============================================================================

-- Event correlation by business key
CREATE OR REPLACE FUNCTION correlate_events(
    p_tenant_id UUID,
    p_business_key JSONB,
    p_event_types TEXT[]
) RETURNS TABLE(
    event_id UUID,
    event_type TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT e.id, e.event_type, e.payload, e.created_at
    FROM event_store e
    WHERE e.tenant_id = p_tenant_id
      AND e.event_type = ANY(p_event_types)
      AND e.business_key @> p_business_key
    ORDER BY e.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Latest event per aggregate
CREATE OR REPLACE FUNCTION get_latest_events(
    p_tenant_id UUID,
    p_aggregate_types TEXT[],
    p_limit INT DEFAULT 100
) RETURNS TABLE(
    aggregate_id UUID,
    aggregate_type TEXT,
    event_id UUID,
    event_type TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.aggregate_id,
        e.aggregate_type,
        e.id,
        e.event_type,
        e.payload,
        e.created_at
    FROM event_store e
    WHERE e.tenant_id = p_tenant_id
      AND e.aggregate_type = ANY(p_aggregate_types)
    ORDER BY e.aggregate_id, e.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CROSS-DOMAIN: Aggregate State Rebuild
-- ============================================================================

-- Full state rebuild from events
CREATE OR REPLACE FUNCTION rebuild_aggregate_state(
    p_aggregate_type TEXT,
    p_aggregate_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_state JSONB := '{}'::JSONB;
    v_event RECORD;
BEGIN
    FOR v_event IN
        SELECT payload, event_type
        FROM event_store
        WHERE aggregate_type = p_aggregate_type
          AND aggregate_id = p_aggregate_id
        ORDER BY event_number ASC
    LOOP
        v_state := apply_event_state(v_state, v_event.payload, v_event.event_type);
    END LOOP;

    RETURN v_state;
END;
$$ LANGUAGE plpgsql;

-- Apply single event to state (stub - override per aggregate)
CREATE OR REPLACE FUNCTION apply_event_state(
    p_state JSONB,
    p_payload JSONB,
    p_event_type TEXT
) RETURNS JSONB AS $$
BEGIN
    RETURN p_state || p_payload;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CROSS-DOMAIN: Data Export Utilities
-- ============================================================================

-- Export tenant data as JSON
CREATE OR REPLACE FUNCTION export_tenant_data(
    p_tenant_id UUID,
    p_tables TEXT[]
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::JSONB;
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY p_tables
    LOOP
        EXECUTE format('SELECT jsonb_agg(row_to_json(t)) FROM (SELECT * FROM %I WHERE tenant_id = $1) t', v_table)
        USING p_tenant_id
        INTO v_result;
    END LOOP;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CROSS-DOMAIN: Performance Utilities
-- ============================================================================

-- Query performance analysis
CREATE OR REPLACE FUNCTION analyze_query_performance(
    p_sql TEXT
) RETURNS TABLE(
    plan JSONB,
    execution_time_ms NUMERIC
) AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_plan JSONB;
BEGIN
    v_start_time := clock_timestamp();
    
    EXPLAIN (FORMAT JSON) INTO v_plan
    EXECUTE p_sql;

    RETURN QUERY
    SELECT v_plan, EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
END;
$$ LANGUAGE plpgsql;

-- Index usage analysis
CREATE OR REPLACE FUNCTION analyze_index_usage()
RETURNS TABLE(
    table_name TEXT,
    index_name TEXT,
    index_scans BIGINT,
    index_size_bytes BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.relname::TEXT,
        i.relname::TEXT,
        s.idx_scan::BIGINT,
        pg_relation_size(i.oid)::BIGINT
    FROM pg_class t
    JOIN pg_index ix ON ix.indrelid = t.oid
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_stat_user_indexes s ON s.indexrelid = i.oid
    WHERE t.relkind = 'r'
    ORDER BY s.idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CROSS-DOMAIN: Data Validation Utilities
-- ============================================================================

-- Validate required fields
CREATE OR REPLACE FUNCTION validate_required_fields(
    p_data JSONB,
    p_required_fields TEXT[]
) RETURNS TEXT[] AS $$
DECLARE
    v_missing TEXT[] := '{}';
    v_field TEXT;
BEGIN
    FOREACH v_field IN ARRAY p_required_fields
    LOOP
        IF p_data ? v_field = FALSE OR p_data->>v_field IS NULL OR p_data->>v_field = '' THEN
            v_missing := array_append(v_missing, v_field);
        END IF;
    END LOOP;

    RETURN v_missing;
END;
$$ LANGUAGE plpgsql;

-- Validate field types
CREATE OR REPLACE FUNCTION validate_field_types(
    p_data JSONB,
    p_schema JSONB  -- {"field_name": "type", ...}
) RETURNS BOOLEAN AS $$
DECLARE
    v_field TEXT;
    v_expected_type TEXT;
    v_actual_type TEXT;
BEGIN
    FOR v_field, v_expected_type IN
        SELECT key, value::TEXT FROM jsonb_each_text(p_schema)
    LOOP
        IF p_data ? v_field THEN
            v_actual_type := jsonb_typeof(p_data->v_field);
            IF v_expected_type = 'string' AND v_actual_type != 'string' THEN RETURN FALSE; END IF;
            IF v_expected_type = 'number' AND v_actual_type NOT IN('number', 'integer') THEN RETURN FALSE; END IF;
            IF v_expected_type = 'boolean' AND v_actual_type != 'boolean' THEN RETURN FALSE; END IF;
            IF v_expected_type = 'object' AND v_actual_type != 'object' THEN RETURN FALSE; END IF;
            IF v_expected_type = 'array' AND v_actual_type != 'array' THEN RETURN FALSE; END IF;
        END IF;
    END LOOP;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CROSS-DOMAIN: Bulk Operations
-- ============================================================================

-- Bulk event insert with validation
CREATE OR REPLACE FUNCTION bulk_insert_events(
    p_events JSONB  -- [{"aggregate_type": "...", "payload": {...}}, ...]
) RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_event JSONB;
BEGIN
    FOR v_event IN SELECT * FROM jsonb_array_elements(p_events)
    LOOP
        BEGIN
            INSERT INTO event_store (aggregate_type, aggregate_id, event_type, payload, tenant_id, business_key)
            VALUES (
                v_event->>'aggregate_type',
                COALESCE((v_event->>'aggregate_id')::UUID, gen_random_uuid()),
                v_event->>'event_type',
                v_event->>'payload',
                v_event->>'tenant_id'::UUID,
                v_event->>'business_key'::JSONB
            );
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to insert event: %', SQLERRM;
        END;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CROSS-DOMAIN: Migration Helpers
-- ============================================================================

-- Record migration version
CREATE OR REPLACE FUNCTION record_migration(
    p_version TEXT,
    p_description TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO schema_migrations (version, applied_at, description)
    VALUES (p_version, NOW(), p_description)
    ON CONFLICT (version) DO UPDATE
    SET applied_at = NOW(), description = p_description;
END;
$$ LANGUAGE plpgsql;

-- Verify table exists with columns
CREATE OR REPLACE FUNCTION verify_table_schema(
    p_table_name TEXT,
    p_expected_columns TEXT[]
) RETURNS BOOLEAN AS $$
DECLARE
    v_actual_columns TEXT[];
BEGIN
    SELECT array_agg(column_name::TEXT) INTO v_actual_columns
    FROM information_schema.columns
    WHERE table_name = p_table_name;

    RETURN v_actual_columns @> p_expected_columns;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FINAL: System Health Check
-- ============================================================================

CREATE OR REPLACE FUNCTION system_health_check()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    details JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'event_store_count'::TEXT, 
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END,
           jsonb_build_object('count', COUNT(*))
    FROM event_store;

    RETURN QUERY
    SELECT 'tenants_count'::TEXT,
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END,
           jsonb_build_object('count', COUNT(*))
    FROM tenants;

    RETURN QUERY
    SELECT 'users_count'::TEXT,
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END,
           jsonb_build_object('count', COUNT(*))
    FROM users;
END;
$$ LANGUAGE plpgsql;

-- Final output
SELECT 'Phase 5 cross-domain utilities complete' AS status, NOW() AS timestamp;