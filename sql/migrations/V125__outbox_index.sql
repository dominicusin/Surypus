-- Indexes for outbox pattern performance
CREATE INDEX IF NOT EXISTS idx_outbox_unpublished
ON event_outbox(published, created_at) WHERE published = FALSE;

CREATE INDEX IF NOT EXISTS idx_outbox_aggregate
ON event_outbox(aggregate_id, created_at);
