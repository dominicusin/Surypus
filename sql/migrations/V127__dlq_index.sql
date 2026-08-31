-- DLQ indexes for faster retries and cleanup
CREATE INDEX IF NOT EXISTS idx_dlq_unresolved
ON event_dlq(resolved, last_error_at) WHERE resolved = FALSE;

CREATE INDEX IF NOT EXISTS idx_dlq_retry
ON event_dlq(retry_count, last_error_at);