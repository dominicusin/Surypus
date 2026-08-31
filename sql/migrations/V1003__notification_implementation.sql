-- Migration V1003: Notification implementation
-- Creates the notification table and supporting functions for the Surypus notification system.
-- All statements use IF NOT EXISTS / CREATE OR REPLACE for idempotency.
-- Follows existing migration style (V182, V219).

-- ============================================================================
-- 1. Notification table (matching Notifications.hs column layout)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification (
    id          BIGSERIAL PRIMARY KEY,
    ntype       INTEGER NOT NULL DEFAULT 1,
    priority    INTEGER NOT NULL DEFAULT 3,
    recipient_id BIGINT NOT NULL,
    subject     TEXT NOT NULL,
    body        TEXT,
    status      INTEGER NOT NULL DEFAULT 1,  -- 0=draft,1=pending,2=sent,3=delivered,4=read,5=archived
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_recipient ON notification(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notification_status ON notification(status);
CREATE INDEX IF NOT EXISTS idx_notification_created ON notification(created_at DESC);

-- ============================================================================
-- 2. Extend notification_prefs (created by V182) with BIGINT user_id for Haskell compat
-- ============================================================================
-- V182 already creates notification_prefs with id UUID, user_id UUID.
-- We add usr_id BIGINT so the Haskell code (which uses Int64) can query directly.
ALTER TABLE IF EXISTS notification_prefs
  ADD COLUMN IF NOT EXISTS usr_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_notification_prefs_usr_id
  ON notification_prefs(usr_id);

-- ============================================================================
-- 3. notification_create function
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_create(
    p_recipient_id BIGINT,
    p_subject TEXT,
    p_body TEXT DEFAULT NULL,
    p_ntype INTEGER DEFAULT 1,
    p_priority INTEGER DEFAULT 3
) RETURNS TABLE(id TEXT, subject TEXT, body TEXT, status_text TEXT) AS $$
BEGIN
    RETURN QUERY
    INSERT INTO notification (ntype, priority, recipient_id, subject, body, status)
    VALUES (p_ntype, p_priority, p_recipient_id, p_subject, p_body, 1)
    RETURNING
        notification.id::TEXT,
        notification.subject,
        notification.body,
        CASE notification.status
            WHEN 0 THEN 'draft'
            WHEN 1 THEN 'pending'
            WHEN 2 THEN 'sent'
            WHEN 3 THEN 'delivered'
            WHEN 4 THEN 'read'
            ELSE 'archived'
        END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. notification_mark_read function
-- ============================================================================
DROP FUNCTION IF EXISTS notification_mark_read(BIGINT);
CREATE OR REPLACE FUNCTION notification_mark_read(p_id BIGINT)
RETURNS VOID AS $$
BEGIN
    UPDATE notification
    SET status = 4, read_at = NOW()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. notify_event function
-- Creates notifications for all users matching an event type using notification_prefs.
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_event(
    p_event_type TEXT,
    p_subject TEXT,
    p_body TEXT,
    p_ntype INTEGER DEFAULT 1
) RETURNS SETOF BIGINT AS $$
DECLARE
    v_pref RECORD;
    v_notif_id BIGINT;
BEGIN
    -- Find all users who have this event type enabled (or all events)
    FOR v_pref IN
        SELECT COALESCE(np.usr_id, np.user_id::BIGINT) AS recipient_id
        FROM notification_prefs np
        WHERE np.notify_email = TRUE
          AND (np.event_types @> ARRAY[p_event_type] OR np.event_types = '{}')
    LOOP
        INSERT INTO notification (ntype, priority, recipient_id, subject, body, status)
        VALUES (p_ntype, 3, v_pref.recipient_id, p_subject, p_body, 1)
        RETURNING id INTO v_notif_id;

        RETURN NEXT v_notif_id;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. notification_get_digest function
-- Returns unread notifications within a time window for a user.
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_get_digest(
    p_user_id BIGINT,
    p_frequency TEXT DEFAULT 'daily'
) RETURNS TABLE(
    id TEXT,
    subject TEXT,
    body TEXT,
    status_text TEXT,
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    v_interval INTERVAL;
BEGIN
    v_interval := CASE p_frequency
        WHEN 'weekly' THEN INTERVAL '7 days'
        ELSE INTERVAL '1 day'
    END;

    RETURN QUERY
    SELECT
        n.id::TEXT,
        n.subject,
        n.body,
        CASE n.status
            WHEN 0 THEN 'draft'
            WHEN 1 THEN 'pending'
            WHEN 2 THEN 'sent'
            WHEN 3 THEN 'delivered'
            WHEN 4 THEN 'read'
            ELSE 'archived'
        END,
        n.created_at
    FROM notification n
    WHERE n.recipient_id = p_user_id
      AND n.status = 1
      AND n.created_at >= NOW() - v_interval
    ORDER BY n.created_at DESC;
END;
$$ LANGUAGE plpgsql;
