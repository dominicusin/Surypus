-- Migration V1000: Event Store foundation for CQRS
-- Creates the event_store table to store domain events
-- Includes indexes for efficient querying by aggregate and sequence

CREATE TABLE IF NOT EXISTS event_store (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id BIGINT NOT NULL,
    aggregate_type TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_version INTEGER NOT NULL DEFAULT 1,
    event_data JSONB NOT NULL,
    event_metadata JSONB,
    sequence_number BIGINT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fetching events by aggregate in order
CREATE INDEX IF NOT EXISTS idx_event_store_aggregate ON event_store(aggregate_id, aggregate_type, sequence_number);

-- Index for fetching recent events
CREATE INDEX IF NOT EXISTS idx_event_store_created_at ON event_store(created_at);

-- Comment to describe the table
COMMENT ON TABLE event_store is 'Store for domain events in CQRS/Event Sourcing architecture';
