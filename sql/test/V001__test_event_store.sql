-- ============================================================================
-- Event Store Tests
-- ============================================================================
-- Run with: psql -d surypus -f sql/test/V001__test_event_store.sql
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- TEST: Event Type Registration
-- ============================================================================
DO $$
DECLARE
    v_count INT;
BEGIN
    -- Check that event types are registered
    SELECT COUNT(*) INTO v_count FROM event_types;
    
    IF v_count < 10 THEN
        RAISE EXCEPTION 'Expected at least 10 event types, found %', v_count;
    END IF;
    
    RAISE NOTICE '✓ Event types registered: %', v_count;
END;
$$;

-- ============================================================================
-- TEST: Append Event
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_sequence BIGINT;
    v_count INT;
BEGIN
    -- Append a test event
    v_sequence := event_append(
        v_aggregate_id,
        'Inventory',
        'StockReceived',
        '{"test": true}',
        v_tenant_id,
        NULL,
        NULL,
        NULL,
        NULL
    );
    
    -- Verify event was stored
    SELECT COUNT(*) INTO v_count 
    FROM event_store 
    WHERE aggregate_id = v_aggregate_id;
    
    IF v_count != 1 THEN
        RAISE EXCEPTION 'Expected 1 event, found %', v_count;
    END IF;
    
    RAISE NOTICE '✓ Event appended successfully: sequence=%', v_sequence;
END;
$$;

-- ============================================================================
-- TEST: Optimistic Concurrency
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_sequence BIGINT;
BEGIN
    -- First event
    v_sequence := event_append(
        v_aggregate_id,
        'Inventory',
        'StockReceived',
        '{"test": 1}',
        v_tenant_id,
        NULL,
        NULL,
        NULL,
        NULL
    );
    
    -- Try with wrong expected version
    BEGIN
        PERFORM event_append(
            v_aggregate_id,
            'Inventory',
            'StockReceived',
            '{"test": 2}',
            v_tenant_id,
            NULL,
            NULL,
            NULL,
            0
        );
        RAISE EXCEPTION 'Should have thrown concurrency error';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Concurrency conflict%' THEN
            RAISE NOTICE '✓ Optimistic concurrency check works';
        ELSE
            RAISE;
        END IF;
    END;
END;
$$;

-- ============================================================================
-- TEST: Unknown Event Type
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
BEGIN
    BEGIN
        PERFORM event_append(
            v_aggregate_id,
            'Inventory',
            'UnknownEvent',
            '{}',
            v_tenant_id,
            NULL,
            NULL,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Should have thrown unknown event type error';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Unknown event type%' THEN
            RAISE NOTICE '✓ Unknown event type check works';
        ELSE
            RAISE;
        END IF;
    END;
END;
$$;

-- ============================================================================
-- TEST: Get Events by Aggregate
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_events_count INT;
BEGIN
    -- Append multiple events
    PERFORM event_append(v_aggregate_id, 'Inventory', 'StockReceived', '{"n":1}', v_tenant_id, NULL, NULL, NULL, NULL);
    PERFORM event_append(v_aggregate_id, 'Inventory', 'StockReceived', '{"n":2}', v_tenant_id, NULL, NULL, NULL, NULL);
    PERFORM event_append(v_aggregate_id, 'Inventory', 'StockIssued', '{"n":3}', v_tenant_id, NULL, NULL, NULL, NULL);
    
    -- Count events returned
    SELECT COUNT(*) INTO v_events_count 
    FROM event_get_by_aggregate(v_aggregate_id);
    
    IF v_events_count != 3 THEN
        RAISE EXCEPTION 'Expected 3 events, found %', v_events_count;
    END IF;
    
    RAISE NOTICE '✓ Get events by aggregate works';
END;
$$;

-- ============================================================================
-- TEST: Snapshot Creation and Retrieval
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_snapshot_id BIGINT;
    v_retrieved_id BIGINT;
BEGIN
    -- Create snapshot
    v_snapshot_id := snapshot_create(
        v_aggregate_id,
        'Inventory',
        5,
        '{"test": "state"}',
        10
    );
    
    -- Retrieve snapshot
    SELECT snapshot_id INTO v_retrieved_id
    FROM snapshot_get_latest(v_aggregate_id);
    
    IF v_retrieved_id IS NULL THEN
        RAISE EXCEPTION 'Snapshot not retrieved';
    END IF;
    
    IF v_retrieved_id != v_snapshot_id THEN
        RAISE EXCEPTION 'Retrieved wrong snapshot';
    END IF;
    
    RAISE NOTICE '✓ Snapshot creation and retrieval works';
END;
$$;

-- ============================================================================
-- TEST: Outbox Pattern
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_outbox_count INT;
BEGIN
    -- Clear previous test events
    DELETE FROM event_outbox WHERE TRUE;
    
    -- Append event (should auto-create outbox entry via trigger)
    PERFORM event_append(
        v_aggregate_id,
        'Inventory',
        'StockReceived',
        '{"test": "outbox"}',
        v_tenant_id,
        NULL,
        NULL,
        NULL,
        NULL
    );
    
    -- Check outbox entry
    SELECT COUNT(*) INTO v_outbox_count FROM event_outbox WHERE published = FALSE;
    
    IF v_outbox_count != 1 THEN
        RAISE EXCEPTION 'Expected 1 outbox entry, found %', v_outbox_count;
    END IF;
    
    -- Mark as published
    PERFORM outbox_mark_published((SELECT outbox_id FROM event_outbox LIMIT 1));
    
    SELECT COUNT(*) INTO v_outbox_count FROM event_outbox WHERE published = TRUE;
    
    IF v_outbox_count != 1 THEN
        RAISE EXCEPTION 'Expected 1 published outbox entry, found %', v_outbox_count;
    END IF;
    
    RAISE NOTICE '✓ Outbox pattern works';
END;
$$;

-- ============================================================================
-- TEST: Global Sequence
-- ============================================================================
DO $$
DECLARE
    v_seq1 BIGINT;
    v_seq2 BIGINT;
BEGIN
    -- Get two sequence numbers
    SELECT nextval('global_event_sequence') INTO v_seq1;
    SELECT nextval('global_event_sequence') INTO v_seq2;
    
    IF v_seq2 <= v_seq1 THEN
        RAISE EXCEPTION 'Global sequence not incrementing';
    END IF;
    
    RAISE NOTICE '✓ Global sequence works: % -> %', v_seq1, v_seq2;
END;
$$;

-- ============================================================================
-- CLEANUP
-- ============================================================================
-- Remove test data
DELETE FROM event_store WHERE event_data::text LIKE '%"test"%';
DELETE FROM aggregate_snapshots WHERE aggregate_state::text LIKE '%"test"%';
DELETE FROM event_outbox WHERE TRUE;

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'All Event Store Tests Passed!';
RAISE NOTICE '========================================';
