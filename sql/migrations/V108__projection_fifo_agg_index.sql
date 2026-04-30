-- Index to speed up queries by aggregate in FIFO projection
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fifo_lots_aggregate
ON projection_fifo_lots (aggregate_id);
