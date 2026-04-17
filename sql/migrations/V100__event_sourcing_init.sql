-- ============================================================================
-- Surypus Event Sourcing Migration Runner
-- ============================================================================
-- Apply all Event Sourcing migrations in order
-- ============================================================================

\set ON_ERROR_STOP on

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE MIGRATIONS
-- ============================================================================

-- Event Store (must be first)
\i ../event/V001__event_store.sql

-- Kafka Streams
\i ../event/V002__kafka_streams.sql

-- RBAC Schema
\i ../core/V001__rbac_schema.sql

-- ============================================================================
-- AGGREGATE MIGRATIONS
-- ============================================================================

-- Inventory Aggregate
\i ../aggregate/V001__inventory_aggregate.sql

-- Bill Aggregate
\i ../aggregate/V002__bill_aggregate.sql

-- ============================================================================
-- PROJECTION MIGRATIONS
-- ============================================================================

-- FIFO Projection
\i ../projection/V001__fifo_projection.sql

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
