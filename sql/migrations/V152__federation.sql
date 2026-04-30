-- Cross-tenant query support
CREATE OR REPLACE FUNCTION cross_tenant_query(
    p_tenant_ids UUID[],
    p_sql TEXT
) RETURNS TABLE(result JSONB) AS $$
DECLARE
    v_result JSONB;
    v_tenant UUID;
BEGIN
    FOREACH v_tenant IN ARRAY p_tenant_ids
    LOOP
        PERFORM set_config('surypus.tenant_id', v_tenant::TEXT, TRUE);
        RETURN QUERY EXECUTE p_sql;
    END LOOP;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Cross-tenant query failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Tenant export helper
CREATE OR REPLACE FUNCTION export_tenant_data(
    p_tenant_id UUID,
    p_tables TEXT[] DEFAULT ARRAY['event_store', 'aggregates']
) RETURNS TEXT AS $$
DECLARE
    v_table TEXT;
    v_result TEXT := '';
BEGIN
    FOREACH v_table IN ARRAY p_tables
    LOOP
        v_result := v_result || v_table || ': ' || 
            (SELECT COUNT(*)::TEXT FROM event_store WHERE tenant_id = p_tenant_id) || E'\n';
    END LOOP;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;