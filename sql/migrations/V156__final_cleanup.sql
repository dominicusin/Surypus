-- Final cleanup and optimization

-- Drop orphaned aggregates (no events)
DELETE FROM aggregates
WHERE aggregate_id NOT IN (SELECT DISTINCT aggregate_id FROM event_store);

-- Clean up stale locks
UPDATE aggregates SET locked_at = NULL
WHERE locked_at < NOW() - INTERVAL '10 minutes';

-- Reset stuck outbox
UPDATE event_outbox SET published = FALSE
WHERE published = FALSE
  AND created_at < NOW() - INTERVAL '1 day'
  AND publish_attempts > 5;

-- Final analyze
ANALYZE event_store;
ANALYZE aggregates;
ANALYZE event_outbox;

-- Record final migration
PERFORM health_record('migration_v156', 'healthy', 156, 'Final cleanup complete');

RAISE NOTICE 'Migration V156: Final cleanup applied';