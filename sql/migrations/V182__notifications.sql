-- Notification preferences
CREATE TABLE IF NOT EXISTS notification_prefs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    notify_email BOOLEAN DEFAULT TRUE,
    notify_push BOOLEAN DEFAULT TRUE,
    digest_frequency TEXT DEFAULT 'daily',
    event_types TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notification queue
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    channel TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
