-- V397__rbac_canon_queue_priority.sql
-- Add per-item priority to canon_queue to enable prioritized processing
ALTER TABLE IF EXISTS rbac.canon_queue ADD COLUMN IF NOT EXISTS priority INT NOT NULL DEFAULT 0;
