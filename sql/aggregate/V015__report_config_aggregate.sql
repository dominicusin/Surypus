-- ============================================================================
-- Report Config Aggregate (Analytics domain) - Event Sourcing
-- Phase 14: ERP domain expansion. Follows the Bill/Goods/Customer/ProductionOrder
-- aggregate pattern, proving the framework scales to Analytics/reporting.
-- ============================================================================
-- Events:
--   - ReportConfigCreated
--   - ReportConfigToggled
-- ============================================================================

SELECT event_type_register('ReportConfigCreated', 'ReportConfig', NULL);
SELECT event_type_register('ReportConfigToggled', 'ReportConfig', NULL);

CREATE TABLE IF NOT EXISTS projection_report_config (
    config_id   UUID PRIMARY KEY,
    title       TEXT,
    query       TEXT,
    refresh_minutes INT,
    enabled     BOOLEAN,
    tenant_id   UUID,
    version     INT DEFAULT 0,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Command: Create report config
CREATE OR REPLACE FUNCTION cmd_report_config_create(
    p_aggregate_id UUID, p_tenant_id UUID, p_user_id UUID,
    p_title TEXT, p_query TEXT, p_refresh_minutes INT DEFAULT NULL, p_enabled BOOLEAN DEFAULT TRUE,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE v_event_data JSONB; v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('title', p_title, 'query', p_query, 'refresh_minutes', p_refresh_minutes, 'enabled', p_enabled);
    v_sequence := event_append(p_aggregate_id, 'ReportConfig', 'ReportConfigCreated', v_event_data, p_tenant_id, p_user_id, NULL, NULL, p_expected_version);
    PERFORM projection_handle_report_config(p_aggregate_id, 'ReportConfigCreated', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Toggle report config enabled
CREATE OR REPLACE FUNCTION cmd_report_config_toggle(
    p_aggregate_id UUID, p_tenant_id UUID, p_user_id UUID, p_enabled BOOLEAN,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE v_event_data JSONB; v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('enabled', p_enabled);
    v_sequence := event_append(p_aggregate_id, 'ReportConfig', 'ReportConfigToggled', v_event_data, p_tenant_id, p_user_id, NULL, NULL, p_expected_version);
    PERFORM projection_handle_report_config(p_aggregate_id, 'ReportConfigToggled', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Projection: apply a ReportConfig event to the read model.
CREATE OR REPLACE FUNCTION projection_handle_report_config(
    p_aggregate_id UUID, p_event_type TEXT, p_event_data JSONB, p_tenant_id UUID
)
RETURNS VOID AS $$
BEGIN
    IF p_event_type = 'ReportConfigCreated' THEN
        INSERT INTO projection_report_config (config_id, title, query, refresh_minutes, enabled, tenant_id, version, updated_at)
        VALUES (p_aggregate_id, p_event_data->>'title', p_event_data->>'query',
                (p_event_data->>'refresh_minutes')::INT, (p_event_data->>'enabled')::BOOLEAN, p_tenant_id, 1, CURRENT_TIMESTAMP)
        ON CONFLICT (config_id) DO UPDATE SET title=EXCLUDED.title, query=EXCLUDED.query,
            refresh_minutes=EXCLUDED.refresh_minutes, enabled=EXCLUDED.enabled, version=EXCLUDED.version, updated_at=CURRENT_TIMESTAMP;
    ELSIF p_event_type = 'ReportConfigToggled' THEN
        UPDATE projection_report_config SET enabled=(p_event_data->>'enabled')::BOOLEAN, version=version+1, updated_at=CURRENT_TIMESTAMP WHERE config_id=p_aggregate_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
