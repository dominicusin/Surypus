-- V406__rbac_canon_priority_indexer.sql
-- Create index to support rapid prioritization during dequeue
CREATE INDEX IF NOT EXISTS idx_canon_queue_priority ON rbac.canon_queue (priority DESC NULLS LAST, enqueued_at ASC);
