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
COMMENT ON COLUMN event_store.id is 'Unique identifier for the event';
COMMENT ON COLUMN event_store.aggregate_id is 'Identifier of the aggregate this event belongs to';
COMMENT ON COLUMN event_store.aggregate_type is 'Type of the aggregate (e.g., account, invoice)';
COMMENT ON COLUMN event_store.event_type is 'Type of the event (e.g., AccountCreated, JournalEntryPosted)';
COMMENT ON COLUMN event_store.event_version is 'Version of the event schema';
COMMENT ON COLUMN event_store.event_data is 'Payload of the event as JSON';
COMMENT ON COLUMN event_store.event_metadata is 'Metadata about the event (e.g., causation, correlation) as JSON';
COMMENT ON COLUMN event_store.sequence_number is 'Sequence number of the event within the aggregate';
COMMENT ON COLUMN event_store.occurred_at is 'Timestamp when the event occurred';
COMMENT ON COLUMN event_store.created_at is 'Timestamp when the event was stored';
