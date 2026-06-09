-- V1005: Event store snapshots and schema versioning
-- Adds event_schema_version to event_store and creates event_snapshot table

-- Add schema versioning to event_store
ALTER TABLE event_store ADD COLUMN IF NOT EXISTS event_schema_version INTEGER NOT NULL DEFAULT 1;

-- Create event_snapshot table with UNIQUE constraint on (aggregate_id, aggregate_type, version)
CREATE TABLE IF NOT EXISTS event_snapshot (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id BIGINT NOT NULL,
    aggregate_type TEXT NOT NULL,
    version INTEGER NOT NULL,
    last_sequence_number BIGINT NOT NULL,
    snapshot_data TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (aggregate_id, aggregate_type, version)
);

CREATE INDEX IF NOT EXISTS idx_event_snapshot_lookup ON event_snapshot(aggregate_id, aggregate_type, version DESC);

COMMENT ON TABLE event_snapshot IS 'Snapshots of aggregate state for efficient replay';
COMMENT ON COLUMN event_snapshot.aggregate_id IS 'Identifier of the aggregate';
COMMENT ON COLUMN event_snapshot.aggregate_type IS 'Type of the aggregate';
COMMENT ON COLUMN event_snapshot.version IS 'Aggregate version at which snapshot was taken';
COMMENT ON COLUMN event_snapshot.last_sequence_number IS 'Last event sequence number covered by this snapshot';
COMMENT ON COLUMN event_snapshot.snapshot_data IS 'Serialized aggregate state as JSON';
COMMENT ON COLUMN event_snapshot.created_at IS 'When the snapshot was created';
