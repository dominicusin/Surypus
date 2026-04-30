-- Notification queue
CREATE TABLE IF NOT EXISTS notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL,
    user_id UUID,
    title TEXT NOT NULL,
    body TEXT,
    notification_type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Notification preferences
CREATE TABLE IF NOT EXISTS notification_prefs (
    pref_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    email_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    digest_interval INTERVAL DEFAULT '1 day'
);

-- Create notification
CREATE OR REPLACE FUNCTION notify_user(
    p_tenant_id UUID,
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT DEFAULT NULL,
    p_type TEXT DEFAULT 'info'
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO notifications (tenant_id, user_id, title, body, notification_type, created_at)
    VALUES (p_tenant_id, p_user_id, p_title, p_body, p_type, NOW())
    RETURNING notification_id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Mark as read
CREATE OR REPLACE FUNCTION notification_mark_read(p_notification_id BIGINT) RETURNS VOID AS $$
BEGIN
    UPDATE notifications SET is_read = TRUE WHERE notification_id = p_notification_id;
END;
$$ LANGUAGE plpgsql;