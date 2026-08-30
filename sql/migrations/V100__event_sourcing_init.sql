-- ============================================================================
-- Surypus Event Sourcing Migration Runner
-- ============================================================================
-- NOTE: The Event Sourcing schema (event_store, event_append, kafka streams,
-- RBAC, aggregates, projections) is applied by the individual migration files
-- (sql/event/V001, sql/core/V001__rbac_schema, sql/aggregate/V001-V002,
-- sql/projection/V001) which are versioned BELOW V100 and therefore applied
-- earlier in the ordered migration run. This file no longer re-\i includes them
-- (re-including would re-create triggers without IF NOT EXISTS and fail on a
-- second apply). It only verifies the objects exist.
-- ============================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify all objects were created
DO $$
DECLARE
    v_count INT;
BEGIN
    -- Check event_store table
    SELECT COUNT(*) INTO v_count 
    FROM information_schema.tables 
    WHERE table_name = 'event_store';
    
    IF v_count = 0 THEN
        RAISE EXCEPTION 'event_store table not created';
    END IF;
    
    -- Check core functions
    SELECT COUNT(*) INTO v_count 
    FROM information_schema.routines 
    WHERE routine_name = 'event_append';
    
    IF v_count = 0 THEN
        RAISE EXCEPTION 'event_append function not created';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Event Sourcing Migrations Complete!';
    RAISE NOTICE '========================================';
END;
$$;
