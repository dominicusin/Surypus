-- Index to speed up aggregation rebuilds and event queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_agg_ver
ON event_store (aggregate_id, event_version);
