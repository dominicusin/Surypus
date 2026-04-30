-- ============================================================================
-- Projection Audit Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_audit_count INT;
BEGIN
    -- Clear previous test data
    DELETE FROM projection_audit WHERE TRUE;

    -- Append event (should trigger projection and audit)
    PERFORM event_append(
        v_aggregate_id,
        'Inventory',
        'StockReceived',
        '{"test": "audit"}',
        v_tenant_id,
        NULL, NULL, NULL, NULL
    );

    -- Verify audit entry
    SELECT COUNT(*) INTO v_audit_count FROM projection_audit;
    IF v_audit_count < 1 THEN
        RAISE EXCEPTION 'Expected at least 1 audit entry, found %', v_audit_count;
    END IF;

    -- Verify duration_ms is recorded
    IF EXISTS (SELECT 1 FROM projection_audit WHERE duration_ms IS NULL) THEN
        RAISE EXCEPTION 'duration_ms should be recorded';
    END IF;

    RAISE NOTICE '✓ Projection audit with duration works';
END;
$$;

-- ============================================================================
-- CLEANUP
-- ============================================================================
DELETE FROM projection_audit WHERE TRUE;

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'Projection Audit Test Passed!';
RAISE NOTICE '========================================';